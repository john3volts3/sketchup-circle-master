# encoding: UTF-8
#-------------------------------------------------------------------------------
#
#  Circle Master - automatic tests (development tool, not shipped in the .rbz).
#  Runner adapted from Solid Progress (tools/tests/run_tests.rb).
#
#  Fully automatic, from PowerShell (SketchUp closed):
#    tools/tests/run_tests.ps1            (SketchUp 2021, then Make 2017)
#  It deploys the plugin, starts each SketchUp with -RubyStartup on this file,
#  waits for the report and closes SketchUp.
#
#  By hand, in the Ruby console of SketchUp:
#    load "<project folder>/tools/tests/run_tests.rb"
#
#  The plugin files installed in SketchUp are reloaded first. The tests run
#  in a new model in millimetres (the current one is never changed); message
#  boxes and preference writes are recorded instead of being done. Steps are
#  chained with timers, so that SketchUp handles its events between them.
#
#  Tests: input parser (vcb_parser_cases.rb, real to_l), commands, and the
#  comparison of the reconstruction engines (engine_cases.rb: INFO cases,
#  they never fail the run).
#
#  Report: Ruby console and results/latest-<SketchUp major version>.txt.
#
#-------------------------------------------------------------------------------

verbose = $VERBOSE
$VERBOSE = nil

module CircleMasterTests
  path = File.expand_path(__FILE__)
  path.force_encoding('UTF-8') if path.respond_to?(:force_encoding)
  TESTS_DIR = File.dirname(path)
  RESULTS_DIR = File.join(TESTS_DIR, 'results')
  STEP_DELAY = 0.5
  LOG = '[Circle Master tests]'.freeze

  # One test: checks, notes and the phases still to run. An INFO case
  # reports its checks but never fails the run.
  class Case
    attr_reader :name, :checks, :notes, :phases
    attr_accessor :skipped, :info

    def initialize(name)
      @name = name
      @checks = []
      @notes = []
      @phases = []
      @skipped = nil
      @info = false
    end

    # Runs the block after a delay, once SketchUp has handled its events.
    def later(&block)
      @phases << block
    end

    def check(ok, label, detail = nil)
      @checks << [ok ? true : false, label, detail]
      ok
    end

    def note(text)
      @notes << text
    end

    def skip(reason)
      @skipped = reason
    end

    def failed?
      @checks.any? { |c| !c[0] }
    end
  end

  # -------------------------------------------------------------------
  # Runner
  # -------------------------------------------------------------------

  def self.run
    @started = Time.now
    @cases = []
    @messages = []
    @status = []
    @writes = []
    @tests = []
    @engine_rows = []
    @vcb = {}
    @inputs = []
    @answers = []
    reload_plugin
    define_tests
    hook
    prepare_model(0) { next_test }
  rescue => e
    fatal(e)
  end

  def self.messages
    @messages
  end

  def self.status
    @status
  end

  def self.writes
    @writes
  end

  def self.engine_rows
    @engine_rows
  end

  # Last label and value written to the Measurements box.
  def self.vcb
    @vcb
  end

  # Answers given to the next UI.inputbox calls (arrays of values; none
  # left: cancelled) and UI.messagebox calls (IDYES, IDNO...; none left:
  # IDYES for a question, IDOK otherwise).
  def self.inputs
    @inputs
  end

  def self.answers
    @answers
  end

  SETTINGS_IVARS = %i[@segments @input_mode @coord_mode].freeze

  # Before each test: known settings in memory (48 segments, diameter,
  # coordinates auto), whatever the preferences of this PC; after it, the
  # former values back. Nothing is written to the preferences.
  def self.save_state
    settings = CircleMaster::Settings
    @saved_state = {
      settings: SETTINGS_IVARS.map { |v| [v, settings.instance_variable_get(v)] },
      previous: CircleMaster::CircleTool.previous
    }
    settings.instance_variable_set(:@segments, 48)
    settings.instance_variable_set(:@input_mode, 'diameter')
    settings.instance_variable_set(:@coord_mode, 'auto')
    @inputs.clear
    @answers.clear
  end

  def self.restore_state
    return unless @saved_state
    model = Sketchup.active_model
    model.select_tool(nil)
    close_all(model)
    model.selection.clear
    settings = CircleMaster::Settings
    @saved_state[:settings].each { |v, value| settings.instance_variable_set(v, value) }
    CircleMaster::CircleTool.previous = @saved_state[:previous]
    @saved_state = nil
  end

  def self.schedule(&block)
    timer = UI.start_timer(STEP_DELAY, false) do
      UI.stop_timer(timer)
      begin
        block.call
      rescue => e
        fatal(e)
      end
    end
  end

  def self.test(name, info: false, &block)
    @tests << [name, info, block]
  end

  def self.next_test
    restore_state
    # Unused definitions that appeared during the previous test.
    if @cases.last
      model = Sketchup.active_model
      now = unused_new_definitions(model)
      fresh = now - (@unused_seen || [])
      @unused_seen = now
      @cases.last.note("unused definition(s) appeared: #{fresh.map(&:name).join(', ')}") unless fresh.empty?
    end
    if @tests.empty?
      finish
      return
    end
    name, info, block = @tests.shift
    c = Case.new(name)
    c.info = info
    @cases << c
    Sketchup.status_text = "#{LOG} #{name}"
    save_state
    guarded(c) { block.call(c, Sketchup.active_model) }
    schedule { next_phase(c) }
  end

  def self.next_phase(c)
    phase = c.phases.shift
    if phase.nil? || c.skipped
      next_test
      return
    end
    guarded(c) { phase.call }
    schedule { next_phase(c) }
  end

  def self.guarded(c)
    yield
  rescue => e
    c.check(false, "exception: #{e.class}: #{e.message}", e.backtrace.first(4).join(' | '))
    c.phases.clear
  end

  def self.fatal(e)
    @fatal = "#{e.class}: #{e.message} | #{e.backtrace.first(6).join(' | ')}"
    restore_state
    finish
  end

  # -------------------------------------------------------------------
  # Setup
  # -------------------------------------------------------------------

  def self.reload_plugin
    raise 'Circle Master is not loaded in this SketchUp' unless defined?(CircleMaster::FILES)
    # Constants are redefined: silence the "already initialized" warnings.
    verbose = $VERBOSE
    $VERBOSE = nil
    CircleMaster::FILES.each { |f| load File.join(CircleMaster::PLUGIN_DIR, "#{f}.rb") }
    load File.join(TESTS_DIR, 'vcb_parser_cases.rb')
    load File.join(TESTS_DIR, 'engine_cases.rb')
    load File.join(TESTS_DIR, 'command_cases.rb')
  ensure
    $VERBOSE = verbose
  end

  # Message boxes, input boxes and preference writes recorded instead of
  # done (prepared answers); status texts and the Measurements box recorded
  # too.
  def self.hook
    tests = self
    ui = UI.singleton_class
    ui.send(:alias_method, :cm_tests_messagebox, :messagebox) unless ui.method_defined?(:cm_tests_messagebox)
    UI.define_singleton_method(:messagebox) do |*args|
      tests.messages << args.first.to_s
      answer = tests.answers.shift
      answer || (args[1] == MB_YESNO ? IDYES : IDOK)
    end
    ui.send(:alias_method, :cm_tests_inputbox, :inputbox) unless ui.method_defined?(:cm_tests_inputbox)
    UI.define_singleton_method(:inputbox) do |*_args|
      tests.inputs.shift || false
    end
    su = Sketchup.singleton_class
    su.send(:alias_method, :cm_tests_status_text=, :status_text=) unless su.method_defined?(:cm_tests_status_text=)
    Sketchup.define_singleton_method(:status_text=) do |text|
      tests.status << text.to_s
      Sketchup.send(:cm_tests_status_text=, text)
    end
    su.send(:alias_method, :cm_tests_vcb_label=, :vcb_label=) unless su.method_defined?(:cm_tests_vcb_label=)
    Sketchup.define_singleton_method(:vcb_label=) do |text|
      tests.vcb[:label] = text.to_s
      Sketchup.send(:cm_tests_vcb_label=, text)
    end
    su.send(:alias_method, :cm_tests_vcb_value=, :vcb_value=) unless su.method_defined?(:cm_tests_vcb_value=)
    Sketchup.define_singleton_method(:vcb_value=) do |text|
      tests.vcb[:value] = text.to_s
      Sketchup.send(:cm_tests_vcb_value=, text)
    end
    su.send(:alias_method, :cm_tests_write_default, :write_default) unless su.method_defined?(:cm_tests_write_default)
    Sketchup.define_singleton_method(:write_default) do |*args|
      tests.writes << args.first(2).join('/')
      true
    end
    @hooked = true
  end

  def self.unhook
    return unless @hooked
    ui = UI.singleton_class
    ui.send(:alias_method, :messagebox, :cm_tests_messagebox)
    ui.send(:alias_method, :inputbox, :cm_tests_inputbox)
    su = Sketchup.singleton_class
    su.send(:alias_method, :status_text=, :cm_tests_status_text=)
    su.send(:alias_method, :vcb_label=, :cm_tests_vcb_label=)
    su.send(:alias_method, :vcb_value=, :cm_tests_vcb_value=)
    su.send(:alias_method, :write_default, :cm_tests_write_default)
    @hooked = false
  end

  # A new model, unsaved and unchanged, emptied of its template content, in
  # millimetres (the parser cases expect it).
  def self.prepare_model(attempt, &after)
    model = Sketchup.active_model
    if model.path.to_s.empty? && !model.modified?
      model.start_operation('Circle Master tests — setup', true)
      model.entities.erase_entities(model.entities.to_a) unless model.entities.length.zero?
      model.commit_operation
      model.selection.clear
      units = model.options['UnitsOptions']
      units['LengthFormat'] = 0 # decimal
      units['LengthUnit'] = 2   # millimetres
      @definitions_before = model.definitions.to_a
      after.call
    elsif attempt < 3
      Sketchup.file_new
      schedule { prepare_model(attempt + 1, &after) }
    else
      raise 'No new empty model: close the current model and run the tests again'
    end
  end

  # Opens +path+ (groups or components) for editing: SketchUp 2020.1+ only.
  def self.open_path?(model)
    model.respond_to?(:active_path=)
  end

  def self.close_all(model)
    return unless open_path?(model) && model.active_path
    model.active_path = nil
  rescue ArgumentError, TypeError
    model.active_path = []
  end

  # Runs the block with the input mode set in memory only.
  def self.with_mode(mode)
    settings = CircleMaster::Settings
    saved = settings.instance_variable_get(:@input_mode)
    settings.instance_variable_set(:@input_mode, mode)
    yield
  ensure
    settings.instance_variable_set(:@input_mode, saved)
  end

  # -------------------------------------------------------------------
  # Geometry and queries
  # -------------------------------------------------------------------

  def self.pt(x, y, z)
    Geom::Point3d.new(x, y, z)
  end

  # Origin of the geometry of test number +k+ (tests never touch each other).
  def self.slot(k)
    pt(k * 5000.mm, 0, 0)
  end

  def self.box(entities, x, y, z, w, d, h, material = nil)
    g = entities.add_group
    f = g.entities.add_face(pt(x, y, z), pt(x + w, y, z), pt(x + w, y + d, z), pt(x, y + d, z))
    f.reverse! if f.normal.z < 0
    f.pushpull(h)
    g.entities.grep(Sketchup::Face).each { |face| face.material = material } if material
    g
  end

  # One group of cylinders along +axis+, a base center at each point.
  def self.cylinders(entities, centers, axis, r, h, segments = 24)
    g = entities.add_group
    centers.each { |c| add_cylinder(g.entities, c, axis, r, h, segments) }
    g
  end

  def self.add_cylinder(entities, center, axis, r, h, segments = 24)
    f = entities.add_face(entities.add_circle(center, axis, r, segments))
    f.reverse! if f.normal.dot(axis) < 0
    f.pushpull(h)
  end

  # One group of truncated cones along +z: radius r1 at each point, r2 at h.
  def self.cones(entities, centers, r1, r2, h, segments = 24)
    g = entities.add_group
    centers.each do |c|
      add_cylinder(g.entities, c, Z_AXIS, r1, h, segments)
      top = pt(c.x, c.y, c.z + h)
      ring = g.entities.grep(Sketchup::Edge).select do |e|
        e.vertices.all? do |v|
          (v.position.z.to_f - top.z.to_f).abs < 1e-6 && v.position.distance(top).to_f < r1 * 1.01
        end
      end
      g.entities.transform_entities(Geom::Transformation.scaling(top, r2 / r1), ring)
    end
    g
  end

  def self.material(model, name, rgb)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  def self.inner(instance)
    instance.is_a?(Sketchup::Group) ? instance.entities : instance.definition.entities
  end

  # Native ArcCurves of +entities+ whose center is at +center+. Distances
  # are compared as Float: a Length compares with SketchUp's tolerance.
  def self.arcs_at(entities, center)
    entities.grep(Sketchup::Edge).map(&:curve).compact.uniq.select do |cv|
      cv.is_a?(Sketchup::ArcCurve) && cv.center.distance(center).to_f < 1e-4
    end
  end

  # Wall faces of the vertical cylinder whose base center is +base+.
  def self.walls_at(entities, base, r)
    entities.grep(Sketchup::Face).select do |f|
      !f.normal.parallel?(Z_AXIS) && f.vertices.all? do |v|
        p = v.position
        Math.hypot(p.x - base.x, p.y - base.y) < r * 1.01
      end
    end
  end

  def self.arc_edges(entities)
    entities.grep(Sketchup::Edge).count { |e| e.curve.is_a?(Sketchup::ArcCurve) }
  end

  def self.unused_new_definitions(model)
    (model.definitions.to_a - (@definitions_before || [])).select do |d|
      d.valid? && !d.group? && d.count_instances.zero?
    end
  end

  # Boolean available in this SketchUp: native (Pro), Solid for Maker
  # (Make), or nil.
  def self.boolean_engine
    return 'native' if Sketchup.is_pro?
    return "Solid for Maker #{SolidForMaker::VERSION}" if defined?(SolidForMaker::SolidOperations)
    nil
  end

  # The solid that holds the result of +op+ ('subtract' or 'union') of
  # +tool+ on +acc+, or nil.
  def self.boolean(op, acc, tool)
    if Sketchup.is_pro?
      op == 'union' ? acc.union(tool) : tool.subtract(acc)
    elsif defined?(SolidForMaker::SolidOperations)
      ops = SolidForMaker::SolidOperations
      ok = op == 'union' ? ops.union(acc, tool) : ops.subtract(acc, tool)
      ok ? acc : nil
    end
  end

  # Geometry of a solid, independent of the order and IDs of its entities
  # (Solid Progress tests).
  def self.shape_signature(solid)
    ents = inner(solid)
    r = ->(v) { v.to_f.round(5) }
    name = ->(x) { x ? x.name : '' }
    faces = ents.grep(Sketchup::Face).map do |f|
      n = f.normal
      pts = f.vertices.map { |v| p = v.position; [r.call(p.x), r.call(p.y), r.call(p.z)] }.sort
      [r.call(f.area), [r.call(n.x), r.call(n.y), r.call(n.z)], name.call(f.material),
       name.call(f.back_material), f.layer.name, f.loops.length, pts]
    end
    edges = ents.grep(Sketchup::Edge)
    curves = edges.map(&:curve).compact.uniq
    {
      faces: faces.sort,
      edges: edges.length,
      soft: edges.count(&:soft?),
      smooth: edges.count(&:smooth?),
      arcs: curves.count { |cv| cv.is_a?(Sketchup::ArcCurve) },
      arc_edges: edges.count { |e| e.curve.is_a?(Sketchup::ArcCurve) },
      volume: solid.volume.round(4),
      manifold: solid.manifold?
    }
  end

  def self.signature_diff(a, b)
    keys = a.keys.select { |k| a[k] != b[k] }
    parts = keys.map do |k|
      next "#{k} #{a[k].inspect} / #{b[k].inspect}" unless k == :faces
      "faces #{a[:faces].length} / #{b[:faces].length}, first only: #{(a[:faces] - b[:faces]).first(2).inspect}, " \
        "second only: #{(b[:faces] - a[:faces]).first(2).inspect}"
    end
    parts.join('; ')[0, 800]
  end

  # -------------------------------------------------------------------
  # Tests
  # -------------------------------------------------------------------

  def self.define_tests
    tests = self

    # P1: the 87 cases of the parser, with the real String#to_l of a model
    # in millimetres.
    test 'P1 Input parser: cases with the real to_l' do |c, _model|
      passed, failed, lines = VcbParserCases.run
      if defined?(Sketchup::RegionalSettings)
        c.note("decimal separator of this PC: #{Sketchup::RegionalSettings.decimal_separator.inspect}")
      end
      c.check(failed.zero?, "#{passed} passed, #{failed} failed")
      lines.select { |l| l.start_with?('FAIL', 'SKIP') }.each { |l| c.note(l) }
    end

    # S1: the Circle tool creates a native circle with its face, in one
    # undoable operation.
    test 'S1 Circle: create a circle, one undo step' do |c, model|
      center = tests.slot(1)
      before = model.entities.length
      tool = CircleMaster::CircleTool.new
      model.select_tool(tool)
      tool.send(:create_circle, center, Z_AXIS, 25.mm, 48)
      arcs = tests.arcs_at(model.entities, center)
      c.check(arcs.length == 1 && arcs.first.count_edges == 48, 'one native circle of 48 segments',
              arcs.map(&:count_edges).inspect)
      c.check(arcs.length == 1 && (arcs.first.radius - 25.mm).abs < 1e-6, 'radius 25 mm')
      c.check(model.entities.length == before + 49, 'its 48 edges and one face',
              "#{model.entities.length - before} entities")
      c.later do
        model.select_tool(nil)
        Sketchup.undo
        c.check(model.entities.length == before, 'one undo step removes it')
      end
    end

    # S2: modify mode of the Circle tool (selected circle): increment, then
    # segment count, through the Measurements box.
    test 'S2 Circle: selected circle, +10 then 36s' do |c, model|
      center = tests.slot(2)
      edges = model.entities.add_circle(center, Z_AXIS, 25.mm, 48)
      edges.first.find_faces
      model.selection.clear
      model.selection.add(edges)
      tool = CircleMaster::CircleTool.new
      model.select_tool(tool)
      view = model.active_view
      tests.with_mode('diameter') { tool.onUserText('+10', view) }
      arcs = tests.arcs_at(model.entities, center)
      c.check(arcs.length == 1 && (arcs.first.radius - 30.mm).abs < 1e-6, '+10 = diameter 60 mm',
              arcs.map { |a| (a.radius.to_f / 1.mm).round(4) }.inspect)
      tool.onUserText('36s', view)
      arcs = tests.arcs_at(model.entities, center)
      c.check(arcs.length == 1 && arcs.first.count_edges == 36, '36s = 36 segments',
              arcs.map(&:count_edges).inspect)
      c.check(arcs.length == 1 && (arcs.first.radius - 30.mm).abs < 1e-6, 'size kept')
      model.select_tool(nil)
    end

    # S3: segment count of a cylinder from its end circle (Resegmenter and
    # Volume of Circle Advanced).
    test 'S3 Circle: cylinder end circle, 48s' do |c, model|
      base = tests.slot(3)
      tests.add_cylinder(model.entities, base, Z_AXIS, 20.mm, 30.mm, 24)
      top = tests.pt(base.x, base.y, 30.mm)
      ring = tests.arcs_at(model.entities, top).first
      next c.check(false, 'cylinder built') unless ring
      model.selection.clear
      model.selection.add(ring.edges)
      tool = CircleMaster::CircleTool.new
      model.select_tool(tool)
      tool.onUserText('48s', model.active_view)
      ends = [base, top].map { |p| tests.arcs_at(model.entities, p) }
      c.check(ends.all? { |a| a.length == 1 && a.first.count_edges == 48 }, 'both ends: one native circle of 48',
              ends.map { |a| a.map(&:count_edges) }.inspect)
      model.select_tool(nil)
    end

    # S4: Cylinder Resize Tool on a native cylinder: value, increment, undo.
    test 'S4 Cylinder Resize Tool: 52, then --1, one undo step' do |c, model|
      base = tests.slot(4)
      tests.add_cylinder(model.entities, base, Z_AXIS, 25.mm, 20.mm, 24)
      top = tests.pt(base.x, base.y, 20.mm)
      wall = tests.walls_at(model.entities, base, 25.mm)
      c.check(wall.length == 24, 'wall of 24 faces selected', wall.length.to_s)
      model.selection.clear
      model.selection.add(wall)
      tool = CircleMaster::ResizeTool.new
      model.select_tool(tool)
      view = model.active_view
      radii = lambda do
        [base, top].map { |p| tests.arcs_at(model.entities, p).map { |a| (a.radius.to_f / 1.mm).round(4) } }
      end
      tests.with_mode('diameter') { tool.onUserText('52', view) }
      c.check(radii.call == [[26.0], [26.0]], '52 = diameter 52 mm at both ends', radii.call.inspect)
      tests.with_mode('diameter') { tool.onUserText('--1', view) }
      c.check(radii.call == [[26.5], [26.5]], '--1 = +1 mm', radii.call.inspect)
      c.later do
        model.select_tool(nil)
        Sketchup.undo
        c.check(radii.call == [[26.0], [26.0]], 'one undo step goes back to 52 mm', radii.call.inspect)
      end
    end

    # S5: segment input refused by the cylinder resizing, nothing changed.
    # S5: segment count in Cylinder Resize Tool (EF-12; refused by Cylinder
    # Resize 0.3.0).
    test 'S5 Cylinder Resize Tool: 36s changes the segment count' do |c, model|
      base = tests.slot(5)
      tests.add_cylinder(model.entities, base, Z_AXIS, 25.mm, 20.mm, 24)
      wall = tests.walls_at(model.entities, base, 25.mm)
      model.selection.clear
      model.selection.add(wall)
      tool = CircleMaster::ResizeTool.new
      model.select_tool(tool)
      tool.onUserText('36s', model.active_view)
      top = tests.pt(base.x, base.y, 20.mm)
      ends = [base, top].map { |p| tests.arcs_at(model.entities, p) }
      c.check(ends.all? { |a| a.length == 1 && a.first.count_edges == 36 && (a.first.radius - 25.mm).abs < 1e-6 },
              'both ends: native, 36 segments, same size', ends.map { |a| a.map(&:count_edges) }.inspect)
      model.select_tool(nil)
    end

    define_engine_tests
    define_command_tests

    # Last: preference writes (intercepted, never done) only to the Circle
    # Master section, never to the former plugins.
    test 'Z1 Preferences: only CircleMaster written (intercepted)' do |c, _model|
      foreign = tests.writes.reject { |w| w.start_with?('CircleMaster/') }
      c.check(foreign.empty?, 'no write to another section', foreign.uniq.join(', '))
      c.note("intercepted writes: #{tests.writes.uniq.join(', ')}") unless tests.writes.empty?
    end
  end

  # -------------------------------------------------------------------
  # Report
  # -------------------------------------------------------------------

  def self.finish
    unhook
    Sketchup.active_model.select_tool(nil)
    lines = report_lines
    puts lines
    Dir.mkdir(RESULTS_DIR) unless File.directory?(RESULTS_DIR)
    major = Sketchup.version.to_i
    File.open(File.join(RESULTS_DIR, "latest-#{major}.txt"), 'w:UTF-8') { |f| f.puts lines }
    File.open(File.join(RESULTS_DIR, "history-#{major}.log"), 'a:UTF-8') { |f| f.puts lines; f.puts }
    Sketchup.status_text = "#{LOG} #{lines.last}"
  rescue => e
    puts "#{LOG} report error: #{e.message}"
  end

  def self.report_lines
    edition = Sketchup.is_pro? ? 'Pro' : 'Make'
    version = defined?(CircleMaster::VERSION) ? CircleMaster::VERSION : '?'
    lines = ["Circle Master tests — SketchUp #{Sketchup.version} #{edition} — Ruby #{RUBY_VERSION} — " \
             "plugin #{version} — #{@started.strftime('%Y-%m-%d %H:%M:%S')}"]
    passed = failed = skipped = info = checks = bad = 0
    (@cases || []).each do |c|
      if c.skipped
        skipped += 1
        lines << "SKIP  #{c.name} — #{c.skipped}"
      elsif c.info
        info += 1
        lines << "INFO  #{c.name}"
      elsif c.failed?
        failed += 1
        lines << "FAIL  #{c.name}"
      else
        passed += 1
        lines << "PASS  #{c.name} (#{c.checks.length} checks)"
      end
      unless c.info || c.skipped
        checks += c.checks.length
        bad += c.checks.count { |k| !k[0] }
      end
      c.checks.each do |ok, label, detail|
        next if ok && !c.failed? && !c.info
        text = "      #{ok ? 'ok' : 'XX'} #{label}"
        text += " — #{detail}" if !ok && detail && !detail.to_s.empty?
        lines << text
      end
      c.notes.each { |n| lines << "      · #{n}" }
    end
    unless (@engine_rows || []).empty?
      lines << 'ENGINES (engine of origin / Circle Master on the same solid; ' \
               'SP Solid Progress, CR Cylinder Resize, CA Circle Advanced)'
      @engine_rows.each { |row| lines << "      #{row}" }
    end
    lines << "FATAL #{@fatal}" if @fatal
    lines << format('DONE  passed=%d failed=%d skipped=%d info=%d checks=%d failed_checks=%d time=%.1fs',
                    passed, failed + (@fatal ? 1 : 0), skipped, info, checks, bad, Time.now - @started)
    lines
  end
end

$VERBOSE = verbose

# Started once SketchUp is idle (also when loaded by -RubyStartup).
unless $cm_tests_no_autorun
  cm_tests_timer = UI.start_timer(1, false) do
    UI.stop_timer(cm_tests_timer)
    CircleMasterTests.run
  end
end
