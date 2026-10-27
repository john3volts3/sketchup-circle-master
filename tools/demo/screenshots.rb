# encoding: UTF-8
#-------------------------------------------------------------------------------
#
#  Circle Master - viewport images for the publication (development tool,
#  not shipped in the .rbz). Started by tools/demo/screenshots.ps1 (SketchUp
#  2021, -RubyStartup); the images are put together by make_images.py.
#
#  Three scenes in a new model in millimetres, simple objects, default
#  colors; the commands of Circle Master are applied as a user would
#  (selection, tool, typed text):
#    a  part with a pin, a hole and rounded corners at 24 segments, then 64s
#       on the circles and 16s on the corners (Circle tool, modify mode)
#    b  two discs of 25 mm, 24 and 64 segments
#    c  block with a hole of 5 mm, 24 segments, Cylinder Resize Tool, 5.2;48s
#  Images (view.write_image): a_before.png, a_after.png, b.png, c_before.png,
#  c_after.png; anchors.json: points to label, in pixels of the images;
#  what was obtained: shots.log.
#
#  Nothing is written in the user's settings (Sketchup.write_default is
#  blocked for the CircleMaster section during the run); message boxes are
#  logged and answered OK.
#
#-------------------------------------------------------------------------------

require 'json'

module CircleMasterShots
  OUT = ENV['CM_SHOTS_DIR'].to_s
  LOG = '[Circle Master shots]'.freeze
  RENDER_SCALE = 2

  def self.log(text)
    puts "#{LOG} #{text}"
    File.open(File.join(OUT, 'shots.log'), 'a:UTF-8') { |f| f.puts text }
  rescue StandardError
    nil
  end

  # --- Steps chained with timers -----------------------------------------

  def self.step(delay = 0.6, &block)
    (@steps ||= []) << [delay, block]
  end

  def self.later(delay, &block)
    timer = UI.start_timer(delay, false) do
      UI.stop_timer(timer)
      block.call
    end
  end

  def self.next_step
    delay, block = @steps.shift
    return finish unless block
    later(delay) do
      begin
        block.call
      rescue StandardError => e
        log("ERROR #{e.class}: #{e.message}\n  #{e.backtrace.first(5).join("\n  ")}")
      end
      next_step
    end
  end

  # --- No settings written, no blocking message box ------------------------

  def self.hook
    su = Sketchup.singleton_class
    su.send(:alias_method, :cm_shots_write_default, :write_default)
    su.send(:define_method, :write_default) do |section, key, value|
      if section.to_s == 'CircleMaster'
        CircleMasterShots.log("write_default blocked: #{key} = #{value.inspect}")
        true
      else
        cm_shots_write_default(section, key, value)
      end
    end
    ui = UI.singleton_class
    ui.send(:alias_method, :cm_shots_messagebox, :messagebox)
    ui.send(:define_method, :messagebox) do |*args|
      CircleMasterShots.log("messagebox: #{args.first}")
      IDOK
    end
  end

  def self.unhook
    Sketchup.singleton_class.send(:alias_method, :write_default, :cm_shots_write_default)
    UI.singleton_class.send(:alias_method, :messagebox, :cm_shots_messagebox)
  end

  # --- Geometry (mm) -------------------------------------------------------

  def self.pt(x, y, z = 0)
    Geom::Point3d.new(x.mm, y.mm, z.mm)
  end

  def self.model
    Sketchup.active_model
  end

  def self.ents
    model.entities
  end

  def self.select(*entities)
    model.selection.clear
    model.selection.add(entities.flatten)
  end

  def self.arcs_at(center)
    ents.grep(Sketchup::Edge).map(&:curve).compact.uniq.select do |cv|
      cv.is_a?(Sketchup::ArcCurve) && cv.center.distance(center).to_f < 1e-4
    end
  end

  # Wall faces of the vertical cylinder of radius r (mm) around (x, y).
  def self.walls_at(x, y, r)
    ents.grep(Sketchup::Face).select do |f|
      !f.normal.parallel?(Z_AXIS) && f.vertices.all? do |v|
        p = v.position
        Math.hypot(p.x - x.mm, p.y - y.mm) < r.mm * 1.01
      end
    end
  end

  # Plate w x d x h (mm) with its corners rounded with radius r (mm, 0: square
  # corners), corner arcs of +seg+ segments.
  def self.plate(w, d, h, r, seg)
    if r > 0
      ents.add_line(pt(r, 0), pt(w - r, 0))
      ents.add_arc(pt(w - r, r), X_AXIS, Z_AXIS, r.mm, -Math::PI / 2, 0, seg)
      ents.add_line(pt(w, r), pt(w, d - r))
      ents.add_arc(pt(w - r, d - r), X_AXIS, Z_AXIS, r.mm, 0, Math::PI / 2, seg)
      ents.add_line(pt(w - r, d), pt(r, d))
      ents.add_arc(pt(r, d - r), X_AXIS, Z_AXIS, r.mm, Math::PI / 2, Math::PI, seg)
      ents.add_line(pt(0, d - r), pt(0, r))
      edge = ents.add_arc(pt(r, r), X_AXIS, Z_AXIS, r.mm, Math::PI, 1.5 * Math::PI, seg).first
      edge.find_faces
      face = edge.faces.first
    else
      face = ents.add_face(pt(0, 0), pt(w, 0), pt(w, d), pt(0, d))
    end
    face.reverse! if face.normal.z < 0
    face.pushpull(h.mm)
  end

  # Native circle of radius r (mm) at (x, y, z) pushed by depth (mm): positive
  # for a pin, minus the thickness for a through hole.
  def self.push_circle(x, y, z, r, depth, seg = 24)
    edges = ents.add_circle(pt(x, y, z), Z_AXIS, r.mm, seg)
    disc = edges.first.faces.find { |f| f.outer_loop.edges.all? { |e| edges.include?(e) } }
    disc.reverse! if disc.normal.z < 0
    disc.pushpull(depth.mm)
  end

  # --- View ----------------------------------------------------------------

  def self.style
    begin
      model.rendering_options['DisplaySketchAxes'] = false
    rescue StandardError
      nil
    end
    units = model.options['UnitsOptions']
    units['LengthFormat'] = 0    # decimal
    units['LengthUnit'] = 2      # millimetres
    units['LengthPrecision'] = 1
  end

  # Perspective view from direction +dir+ (from the target to the eye), all
  # the geometry fitted in the viewport.
  def self.look(dir, fov = 30)
    view = model.active_view
    b = model.bounds
    target = b.center
    eye = target.offset(Geom::Vector3d.new(*dir).normalize, b.diagonal * 3)
    cam = Sketchup::Camera.new(eye, target, Z_AXIS)
    cam.perspective = true
    cam.fov = fov
    view.camera = cam
    view.zoom_extents
  end

  def self.render(name)
    view = model.active_view
    view.invalidate
    path = File.join(OUT, "#{name}.png")
    view.write_image(filename: path, width: view.vpwidth * RENDER_SCALE,
                     height: view.vpheight * RENDER_SCALE, antialias: true, transparent: false)
    log("render #{name}: #{view.vpwidth * RENDER_SCALE} x #{view.vpheight * RENDER_SCALE}")
  end

  # Records where +points+ ({label => Point3d}) are in the image +name+.
  def self.anchors(name, points)
    view = model.active_view
    @anchors ||= {}
    @anchors[name] = {}
    points.each do |label, p|
      q = view.screen_coords(p)
      @anchors[name][label] = [(q.x * RENDER_SCALE).round, (q.y * RENDER_SCALE).round]
    end
  end

  def self.clear_model
    model.select_tool(nil)
    model.selection.clear
    ents.erase_entities(ents.to_a) unless ents.length.zero?
  end

  def self.circle_tool
    tool = CircleMaster::CircleTool.new
    model.select_tool(tool)
    tool
  end

  def self.describe_circles(label, *centers)
    got = centers.map { |c| arcs_at(c).map { |cv| [(cv.radius.to_f / 1.mm).round(3), cv.count_edges] } }
    log("#{label}: #{got.inspect}")
  end

  # --- Scenes --------------------------------------------------------------

  # Part 60 x 40 x 8, rounded corners r 8, pin Ø 16 x 16 high, hole Ø 14.
  # The hole is not tangent to the circle of a rounded corner: Circle Master
  # 1.0.0 then refuses that corner once the hole has 64 segments (see
  # JOURNAL.md, 2026-10-26).
  PIN     = [19, 20].freeze
  HOLE    = [41, 20].freeze
  CORNERS = [[52, 8], [52, 32], [8, 32], [8, 8]].freeze
  VIEW_A  = [1.0, -1.5, 1.25].freeze

  def self.scene_a_anchors(name)
    toward = Geom::Vector3d.new(VIEW_A[0], VIEW_A[1], 0).normalize
    front = ->(x, y, z, r) { pt(x, y, z).offset(toward, r.mm) }
    corner = Geom::Vector3d.new(1, -1, 0).normalize
    anchors(name, 'pin' => front.call(PIN[0], PIN[1], 24, 8),
                  'pin_center' => pt(PIN[0], PIN[1], 24),
                  'hole' => front.call(HOLE[0], HOLE[1], 8, -7),
                  'hole_center' => pt(HOLE[0], HOLE[1], 8),
                  'corner' => pt(52, 8, 4).offset(corner, 8.mm))
  end

  def self.scene_a
    step do
      clear_model
      plate(60, 40, 8, 8, 6)
      push_circle(PIN[0], PIN[1], 8, 8, 16)
      push_circle(HOLE[0], HOLE[1], 8, 7, -8)
      describe_circles('a built (pin top, hole top)', pt(PIN[0], PIN[1], 24), pt(HOLE[0], HOLE[1], 8))
      look(VIEW_A)
    end
    step(1.0) do
      render('a_before')
      scene_a_anchors('a_before')
    end
    step do
      select(arcs_at(pt(PIN[0], PIN[1], 24)).first.edges, arcs_at(pt(HOLE[0], HOLE[1], 8)).first.edges)
      circle_tool.onUserText('64s', model.active_view)
      describe_circles('a 64s (pin top, hole top)', pt(PIN[0], PIN[1], 24), pt(HOLE[0], HOLE[1], 8))
      model.select_tool(nil)
    end
    # One rounded corner at a time, as a user would click its arc.
    CORNERS.each do |x, y|
      step do
        arc = arcs_at(pt(x, y, 8)).first
        next log("a corner #{x},#{y}: no arc") unless arc
        select(arc.edges)
        circle_tool.onUserText('16s', model.active_view)
        describe_circles("a 16s corner #{x},#{y} (bottom, top)", pt(x, y, 0), pt(x, y, 8))
        model.select_tool(nil)
      end
    end
    step do
      model.selection.clear
    end
    step(1.0) do
      render('a_after')
      scene_a_anchors('a_after')
    end
  end

  # Two discs of 25 mm: 24 segments (the native tool after a restart) and 64.
  def self.scene_b
    step do
      clear_model
      [[0, 24], [34, 64]].each do |x, n|
        disc = ents.add_face(ents.add_circle(pt(x, 0), Z_AXIS, 12.5.mm, n))
        disc.reverse! if disc.normal.z < 0
        disc.pushpull(3.mm)
      end
      describe_circles('b discs', pt(0, 0, 3), pt(34, 0, 3))
      look([0.0, -1.0, 1.6])
    end
    step(1.0) do
      render('b')
      anchors('b', 'left' => pt(0, -12.5, 0), 'right' => pt(34, -12.5, 0),
                   'left_top' => pt(0, 12.5, 3), 'right_top' => pt(34, 12.5, 3))
    end
  end

  # Block 16 x 12 x 6 with one through hole of 5 mm.
  HOLE_C = [8, 6].freeze
  VIEW_C = [0.45, -1.0, 1.1].freeze

  def self.scene_c_anchors(name, r)
    toward = Geom::Vector3d.new(VIEW_C[0], VIEW_C[1], 0).normalize
    side = Z_AXIS * toward
    center = pt(HOLE_C[0], HOLE_C[1], 6)
    anchors(name, 'front' => center.offset(toward, r.mm), 'back' => center.offset(toward, -r.mm),
                  'left' => center.offset(side, r.mm), 'right' => center.offset(side, -r.mm),
                  'center' => center)
  end

  def self.scene_c
    step do
      clear_model
      plate(16, 12, 6, 0, 0)
      push_circle(HOLE_C[0], HOLE_C[1], 6, 2.5, -6)
      describe_circles('c built (top, bottom)', pt(HOLE_C[0], HOLE_C[1], 6), pt(HOLE_C[0], HOLE_C[1], 0))
      look(VIEW_C)
    end
    step(1.0) do
      render('c_before')
      scene_c_anchors('c_before', 2.5)
    end
    step do
      select(walls_at(HOLE_C[0], HOLE_C[1], 2.5))
      tool = CircleMaster::ResizeTool.new
      model.select_tool(tool)
      tool.onUserText('5.2;48s', model.active_view)
      describe_circles('c 5.2;48s (top, bottom)', pt(HOLE_C[0], HOLE_C[1], 6), pt(HOLE_C[0], HOLE_C[1], 0))
      model.select_tool(nil)
      model.selection.clear
    end
    step(1.0) do
      render('c_after')
      scene_c_anchors('c_after', 2.6)
    end
  end

  def self.run
    log("SketchUp #{Sketchup.version}, out #{OUT}")
    hook
    style
    @steps = []
    scene_a
    scene_b
    scene_c
    next_step
  rescue StandardError => e
    log("FATAL #{e.class}: #{e.message}")
    finish
  end

  def self.finish
    unhook
    File.open(File.join(OUT, 'anchors.json'), 'w:UTF-8') { |f| f.puts JSON.pretty_generate(@anchors || {}) }
    File.open(File.join(OUT, 'DONE'), 'w') { |f| f.puts 'done' }
    log('DONE')
  end
end

unless CircleMasterShots::OUT.empty?
  cm_shots_timer = UI.start_timer(3, false) do
    UI.stop_timer(cm_shots_timer)
    CircleMasterShots.run
  end
end
