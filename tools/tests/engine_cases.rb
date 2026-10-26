# encoding: UTF-8
# Comparison of the single reconstruction engine of Circle Master
# (CircleMaster::Volume, step 5 of DIRECTIVES_BUNDLE.md) with the engines it
# replaces, as installed in this SketchUp; loaded by run_tests.rb.
#
#   repair    Solid Progress  SolidProcedural::CircleRestore.restore_in_solid
#                             (every broken circle, same size)
#   radius    Cylinder Resize CylinderResize::Detector + Rebuilder, each broken
#                             cylinder 0.1 mm larger in radius
#   segments  Circle Advanced CircleAdvanced::Volume, 24 -> 48 and 24 -> 12
#                             segments from a native end circle
# Circle Master runs the same work through Detector, Resizer.rebuild_body
# and Volume (as Resizer.resize and Resegmenter do).
#
# Each INFO case builds one solid (broken ones: geometry of the T15 tests of
# Solid Progress, 1" there = 10 mm here; booleans native in SketchUp Pro,
# Solid for Maker in Make),
# runs each engine in an operation that is aborted, and compares the results
# (faces, edges, circles, volume, materials) and times. E9 and E10 check
# Circle Master on its own.

module CircleMasterTests
  RADIUS_DELTA = 0.1.mm # radius cases: diameter + 0.2 mm

  # Solid Progress engine available in this SketchUp: its version, or nil.
  def self.sp_version
    return nil unless defined?(SolidProcedural::CircleRestore) &&
                      SolidProcedural::CircleRestore.respond_to?(:restore_in_solid)
    defined?(SolidProcedural::VERSION) ? SolidProcedural::VERSION : '?'
  end

  def self.cr_engine?
    defined?(CylinderResize::Rebuilder) && defined?(CylinderResize::Detector) ? true : false
  end

  def self.ca_engine?
    defined?(CircleAdvanced::Volume) && CircleAdvanced::Volume.respond_to?(:from_curve) ? true : false
  end

  # Solid Progress: every broken circle of +solid+. Returns a summary.
  def self.run_sp(solid)
    restore = SolidProcedural::CircleRestore
    res = if SolidProcedural.respond_to?(:min_arc_segments)
            restore.restore_in_solid(solid, min_arc_segments: SolidProcedural.min_arc_segments)
          else
            restore.restore_in_solid(solid)
          end
    text = "native #{res[:native]}, welded #{res[:welded]}, unwelded #{res[:unwelded]}"
    text += " (#{res[:reasons].map { |r, n| "#{r}: #{n}" }.join(', ')})" unless res[:reasons].empty?
    text
  end

  # Circle Master, as Resizer.resize does: cylinders found once, then each
  # one with a broken end circle rebuilt natively, at its radii plus +delta+.
  def self.run_cm_cylinders(solid, delta)
    ents = inner(solid)
    cylinders, _rejected = CircleMaster::Detector.from_faces(ents.grep(Sketchup::Face))
    broken = cylinders.select { |cyl| cyl.loops.any? { |l| l.arc.nil? } }
    rebuilt = 0
    reasons = Hash.new(0)
    broken.each do |cyl|
      body, reason = CircleMaster::Resizer.rebuild_body(cyl)
      unless body
        reasons[reason] += 1
        next
      end
      plan = cyl.loops.map { |l| [l, l.radius + delta] }
      radii = body.loops.map { |bl| CircleMaster::Resizer.radius_at(plan, bl.center) }
      CircleMaster::Volume.rebuild(ents, body, radii: radii)
      rebuilt += 1
    end
    cylinders_summary(cylinders, broken, rebuilt, reasons)
  end

  # Cylinder Resize 0.3.0 as installed, the same way.
  def self.run_cr_cylinders(solid, delta)
    ents = inner(solid)
    cylinders, _rejected = CylinderResize::Detector.from_faces(ents.grep(Sketchup::Face))
    broken = cylinders.select { |cyl| cyl.loops.any? { |l| l.arc.nil? } }
    rebuilt = 0
    reasons = Hash.new(0)
    broken.each do |cyl|
      reason = CylinderResize::Rebuilder.unsupported_reason(cyl)
      if reason
        reasons[reason] += 1
        next
      end
      CylinderResize::Rebuilder.rebuild(ents, cyl, cyl.loops.map { |l| l.radius + delta })
      rebuilt += 1
    end
    cylinders_summary(cylinders, broken, rebuilt, reasons)
  end

  def self.cylinders_summary(cylinders, broken, rebuilt, reasons)
    text = "#{cylinders.length} cylinder(s), #{broken.length} broken, #{rebuilt} rebuilt"
    text += " (refused: #{reasons.map { |r, n| "#{r}: #{n}" }.join(', ')})" unless reasons.empty?
    text
  end

  # Segment count change to +n+ from the native end circle centered at
  # +center+, with +engine+ (CircleAdvanced::Volume or CircleMaster::Volume).
  def self.run_segments(engine, solid, center, n)
    ents = inner(solid)
    curve = arcs_at(ents, center).first
    raise 'no native circle at the given center' unless curve
    body = engine.from_curve(curve)
    if engine == CircleMaster::Volume
      engine.rebuild(ents, body, segments: n)
    else
      engine.rebuild(ents, body, n)
    end
    "#{n} segments"
  end

  # Segment count change to +n+ of the rounded corner whose arc is centered
  # at +center+, with the Resegmenter of +mod+ (CircleAdvanced or
  # CircleMaster): rounded corners go through Fillet.
  def self.run_fillet(mod, solid, center, n)
    ents = inner(solid)
    arc = arcs_at(ents, center).first
    raise 'no native arc at the given center' unless arc
    mod::Resegmenter.run(ents, [arc.first_edge], n)
    "#{n} segments"
  end

  # Runs the two +engines+ ([[key, label, block], [key, label, block]],
  # reference first, Circle Master second) on +solid+, each in an aborted
  # operation. Checks and notes go to +c+; one report row is added.
  def self.compare(c, model, solid, kind, name, engines)
    before = shape_signature(solid)
    results = {}
    engines.each do |key, label, run|
      model.start_operation('Circle Master tests — engine', true)
      begin
        started = Time.now
        text = run.call
        results[key] = { time: Time.now - started, text: text, sig: shape_signature(solid) }
      rescue => e
        results[key] = { error: "#{e.class}: #{e.message}" }
      ensure
        model.abort_operation
      end
      c.check(shape_signature(solid) == before, "#{kind}, #{label}: model restored after the run")
      r = results[key]
      if r[:error]
        c.check(false, "#{kind}, #{label}: no exception", r[:error])
        next
      end
      c.check(r[:sig][:manifold], "#{kind}, #{label}: still a solid")
      c.note(format('%s, %s: %.2fs, %s; native arcs %d -> %d', kind, label, r[:time], r[:text],
                    before[:arcs], r[:sig][:arcs]))
    end
    ref_key, ref_label = engines[0]
    cm_key = engines[1][0]
    ref = results[ref_key]
    cm = results[cm_key]
    same = ref[:sig] && cm[:sig] && ref[:sig] == cm[:sig] ? true : false
    diff = ref[:sig] && cm[:sig] ? signature_diff(ref[:sig], cm[:sig]) : 'an engine failed'
    c.check(same, "#{kind}: same result as #{ref_label}", diff)
    time = ->(r) { r[:time] ? format('%.2fs', r[:time]) : 'error' }
    arcs = ->(r) { r[:sig] ? r[:sig][:arcs].to_s : '-' }
    abbr = ref_label.split.map { |w| w[0] }.join
    engine_rows << format('%-9s %-38s %s  %s %-7s CM %-7s native arcs: before %d, %s %s, CM %s',
                          kind, name, same ? 'SAME' : 'DIFF', abbr, time.call(ref), time.call(cm),
                          before[:arcs], abbr, arcs.call(ref), arcs.call(cm))
  end

  # Plate of 100 x 100 x 20 mm with a native circle of radius 10 mm and 24
  # segments on its top face, pushed by +depth+ (-20 mm: through hole,
  # -10 mm: blind hole, +20 mm: pin). Returns [group, center of the circle
  # on the top face].
  def self.plate_with_circle(m, x, y, depth)
    g = box(m.entities, x, y, 0, 100.mm, 100.mm, 20.mm)
    center = pt(x + 50.mm, y + 50.mm, 20.mm)
    edges = g.entities.add_circle(center, Z_AXIS, 10.mm, 24)
    disc = g.entities.grep(Sketchup::Face).find { |f| f.outer_loop.edges.all? { |e| edges.include?(e) } }
    disc.pushpull(depth)
    [g, center]
  end

  # Explodes the native curves of +entities+ (all, or those centered at
  # one of +centers+).
  def self.explode_circles(entities, centers = nil)
    curves = entities.grep(Sketchup::Edge).map(&:curve).compact.uniq
    if centers
      curves = curves.select do |cv|
        cv.is_a?(Sketchup::ArcCurve) && centers.any? { |p| cv.center.distance(p).to_f < 1e-4 }
      end
    end
    curves.each { |cv| cv.edges.first.explode_curve if cv.edges.first.valid? }
  end

  def self.define_engine_tests
    tests = self
    x0 = 0
    y0 = 10_000.mm
    step = 1000.mm # between two cases

    # Broken solids: [name, booleans needed?, build(model, x, y) -> [base,
    # [[op, tool], ...]]]
    broken_cases = [
      ['exploded end circles', false, lambda do |m, x, y|
        g = tests.cylinders(m.entities, [tests.pt(x + 50.mm, y + 50.mm, 0)], Z_AXIS, 10.mm, 20.mm)
        tests.explode_circles(g.entities)
        [g, []]
      end],
      # Splitting an edge of a native circle keeps it native: the circles
      # are exploded first, as a boolean leaves them.
      ['exploded end circle with a split point', false, lambda do |m, x, y|
        g = tests.cylinders(m.entities, [tests.pt(x + 50.mm, y + 50.mm, 0)], Z_AXIS, 10.mm, 20.mm)
        tests.explode_circles(g.entities)
        edge = g.entities.grep(Sketchup::Edge).find do |e|
          e.vertices.all? { |v| (v.position.z.to_f - 20.mm.to_f).abs < 1e-6 } && e.faces.length == 2
        end
        edge.split(0.5)
        [g, []]
      end],
      ['plate with 20 holes', true, lambda do |m, x, y|
        centers = (0...5).flat_map do |i|
          (0...4).map { |j| tests.pt(x + (40 + 80 * i).mm, y + (40 + 80 * j).mm, -10.mm) }
        end
        [tests.box(m.entities, x, y, 0, 400.mm, 320.mm, 20.mm),
         [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 8.mm, 40.mm)]]]
      end],
      ['holes near an edge', true, lambda do |m, x, y|
        centers = [[11.5, 50], [50, 12], [100, 50], [150, 50]].map { |a, b| tests.pt(x + a.mm, y + b.mm, -10.mm) }
        [tests.box(m.entities, x, y, 0, 200.mm, 100.mm, 20.mm),
         [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 10.mm, 40.mm)]]]
      end],
      ['truncated cones', true, lambda do |m, x, y|
        cones = [[50, 50], [150, 50], [50, 150]].map { |a, b| tests.pt(x + a.mm, y + b.mm, -10.mm) }
        hole = tests.pt(x + 150.mm, y + 150.mm, -10.mm)
        [tests.box(m.entities, x, y, 0, 200.mm, 200.mm, 30.mm),
         [['subtract', tests.cones(m.entities, cones, 15.mm, 7.mm, 50.mm)],
          ['subtract', tests.cylinders(m.entities, [hole], Z_AXIS, 10.mm, 50.mm)]]]
      end],
      ['counterbores', true, lambda do |m, x, y|
        holes = [50, 120, 190].map { |a| tests.pt(x + a.mm, y + 50.mm, -10.mm) }
        bores = holes.map { |p| tests.pt(p.x, p.y, 20.mm) }
        [tests.box(m.entities, x, y, 0, 240.mm, 100.mm, 30.mm),
         [['subtract', tests.cylinders(m.entities, bores, Z_AXIS, 20.mm, 20.mm)],
          ['subtract', tests.cylinders(m.entities, holes, Z_AXIS, 10.mm, 50.mm)]]]
      end],
      ['pins added by union (one end broken)', true, lambda do |m, x, y|
        centers = [[50, 50], [150, 50], [50, 150], [150, 150]].map { |a, b| tests.pt(x + a.mm, y + b.mm, 10.mm) }
        [tests.box(m.entities, x, y, 0, 200.mm, 200.mm, 20.mm),
         [['union', tests.cylinders(m.entities, centers, Z_AXIS, 10.mm, 40.mm)]]]
      end],
      ['blind holes', true, lambda do |m, x, y|
        centers = [[50, 50], [150, 50], [50, 150], [150, 150]].map { |a, b| tests.pt(x + a.mm, y + b.mm, 20.mm) }
        [tests.box(m.entities, x, y, 0, 200.mm, 200.mm, 40.mm),
         [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 10.mm, 30.mm)]]]
      end]
    ]

    broken_cases.each_with_index do |(name, booleans, build), i|
      test "E#{i + 1} Engines: #{name}", info: true do |c, model|
        unless tests.sp_version || tests.cr_engine?
          next c.skip('neither Solid Progress nor Cylinder Resize installed in this SketchUp')
        end
        next c.skip('no boolean here (SketchUp Pro or Solid for Maker needed)') if booleans && !tests.boolean_engine
        base, steps = build.call(model, x0 + i * step, y0)
        definitions = model.definitions.to_a
        acc = base
        failed = nil
        steps.each_with_index do |(op, tool), k|
          acc = tests.boolean(op, acc, tool)
          next if acc && acc.valid?
          failed = "#{op} #{k + 1} of #{steps.length}"
          break
        end
        # Native booleans with a tool of several solids leave unused
        # definitions (TempInstance#n): removed when the API allows it
        # (SketchUp 2018+), so that the check of the runner only shows those
        # of the plugin.
        temp = (model.definitions.to_a - definitions).select { |d| !d.group? && d.count_instances.zero? }
        unless temp.empty?
          removable = model.definitions.respond_to?(:remove)
          temp.each { |d| model.definitions.remove(d) } if removable
          c.note("the boolean left #{temp.length} unused definition(s)#{removable ? ' (removed by the test)' : ''}")
        end
        next c.check(false, "boolean #{failed} failed (#{tests.boolean_engine})") if failed
        c.note("boolean: #{tests.boolean_engine}") unless steps.empty?
        c.check(acc.manifold?, 'broken solid is a solid')
        if tests.sp_version
          tests.compare(c, model, acc, 'repair', name,
                        [[:sp, 'Solid Progress', -> { tests.run_sp(acc) }],
                         [:cm, 'Circle Master', -> { tests.run_cm_cylinders(acc, 0) }]])
        end
        if tests.cr_engine?
          tests.compare(c, model, acc, 'radius', name,
                        [[:cr, 'Cylinder Resize', -> { tests.run_cr_cylinders(acc, RADIUS_DELTA) }],
                         [:cm, 'Circle Master', -> { tests.run_cm_cylinders(acc, RADIUS_DELTA) }]])
        end
      end
    end

    # Native solids, segment count changes: [name, build(model, x, y) ->
    # [group, center of the native end circle to start from]]
    native_cases = [
      ['cylinder', lambda do |m, x, y|
        center = tests.pt(x + 50.mm, y + 50.mm, 0)
        [tests.cylinders(m.entities, [center], Z_AXIS, 10.mm, 20.mm), center]
      end],
      ['through hole in a plate', ->(m, x, y) { tests.plate_with_circle(m, x, y, -20.mm) }],
      ['blind hole', ->(m, x, y) { tests.plate_with_circle(m, x, y, -10.mm) }],
      ['pin on a plate', ->(m, x, y) { tests.plate_with_circle(m, x, y, 20.mm) }],
      ['truncated cone', lambda do |m, x, y|
        center = tests.pt(x + 50.mm, y + 50.mm, 0)
        [tests.cones(m.entities, [center], 15.mm, 7.mm, 30.mm), center]
      end],
      ['colored cylinder (front and back)', lambda do |m, x, y|
        center = tests.pt(x + 50.mm, y + 50.mm, 0)
        g = tests.cylinders(m.entities, [center], Z_AXIS, 10.mm, 20.mm)
        wall = tests.material(m, 'CM Test Wall', [200, 60, 60])
        back = tests.material(m, 'CM Test Back', [60, 200, 60])
        top = tests.material(m, 'CM Test Top', [60, 60, 200])
        g.entities.grep(Sketchup::Face).each do |f|
          if !f.normal.parallel?(Z_AXIS)
            f.material = wall
            f.back_material = back
          elsif f.normal.z > 0
            f.material = top
          end
        end
        [g, center]
      end]
    ]

    native_cases.each_with_index do |(name, build), i|
      test "N#{i + 1} Engines, segments: #{name}", info: true do |c, model|
        next c.skip('Circle Advanced not installed in this SketchUp') unless tests.ca_engine?
        g, center = build.call(model, x0 + i * step, y0 + 2 * step)
        c.check(g.manifold?, 'native solid is a solid')
        [48, 12].each do |n|
          tests.compare(c, model, g, 'segments', "#{name}, 24 -> #{n}",
                        [[:ca, 'Circle Advanced', -> { tests.run_segments(CircleAdvanced::Volume, g, center, n) }],
                         [:cm, 'Circle Master', -> { tests.run_segments(CircleMaster::Volume, g, center, n) }]])
        end
      end
    end

    # Rounded corners (Fillet, which uses Volume.repair_holes and
    # Volume.tolerance), compared with Circle Advanced.
    [['outer', :add_rounded_block], ['inner', :add_rounded_l]].each_with_index do |(kind, builder), i|
      test "N#{native_cases.length + i + 1} Engines, segments: rounded corner, #{kind}", info: true do |c, model|
        next c.skip('Circle Advanced not installed in this SketchUp') unless tests.ca_engine?
        g = model.entities.add_group
        o = tests.pt(x0 + (native_cases.length + i) * step, y0 + 2 * step, 0)
        center = tests.send(builder, g.entities, o, 40.mm, 10.mm, 20.mm)
        top = tests.pt(center.x, center.y, 20.mm)
        c.check(g.manifold?, 'native solid is a solid')
        [24, 6].each do |n|
          tests.compare(c, model, g, 'segments', "rounded corner, #{kind}, 12 -> #{n}",
                        [[:ca, 'Circle Advanced', -> { tests.run_fillet(CircleAdvanced, g, top, n) }],
                         [:cm, 'Circle Master', -> { tests.run_fillet(CircleMaster, g, top, n) }]])
        end
      end
    end

    # E9: segment count change of Circle Master (Volume), on its own.
    test 'E9 Circle Master engine: cylinder 24 -> 48 segments' do |c, model|
      x = x0 + broken_cases.length * step
      r = 10.mm
      h = 20.mm
      center = tests.pt(x + 50.mm, y0 + 50.mm, 0)
      top = tests.pt(center.x, center.y, h)
      g = tests.cylinders(model.entities, [center], Z_AXIS, r, h, 24)
      ents = g.entities
      wall_mat = tests.material(model, 'CM Test Wall', [200, 60, 60])
      top_mat = tests.material(model, 'CM Test Top', [60, 60, 200])
      ents.grep(Sketchup::Face).each do |f|
        if !f.normal.parallel?(Z_AXIS)
          f.material = wall_mat
        elsif f.normal.z > 0
          f.material = top_mat
        end
      end
      curve = tests.arcs_at(ents, center).first
      model.start_operation('Circle Master tests — segments', true)
      started = Time.now
      begin
        body = CircleMaster::Volume.from_curve(curve)
        CircleMaster::Volume.rebuild(ents, body, segments: 48)
        model.commit_operation
      rescue
        model.abort_operation
        raise
      end
      c.note(format('%.2fs', Time.now - started))
      ends = [center, top].map { |p| tests.arcs_at(ents, p) }
      c.check(ends.all? { |a| a.length == 1 && a.first.count_edges == 48 }, 'both ends: one native circle of 48',
              ends.map { |a| a.map(&:count_edges) }.inspect)
      expected = 48 / 2.0 * Math.sin(2 * Math::PI / 48) * r.to_f**2 * h.to_f
      c.check((g.volume - expected).abs < expected * 1e-4, 'volume of a 48-sided prism',
              "#{g.volume.round(5)} / #{expected.round(5)}")
      c.check(g.manifold?, 'still a solid')
      walls = ents.grep(Sketchup::Face).reject { |f| f.normal.parallel?(Z_AXIS) }
      c.check(walls.length == 48 && walls.all? { |f| f.material == wall_mat }, 'wall: 48 faces, material kept',
              walls.length.to_s)
      tops = ents.grep(Sketchup::Face).select { |f| f.normal.z > 0.99 }
      c.check(tops.length == 1 && tops.first.material == top_mat, 'top face: material kept')
    end

    # E10: radius change of a broken cylinder through Resizer.resize (active
    # context: the model).
    test 'E10 Circle Master resizing: broken cylinder, 50 -> 52 mm' do |c, model|
      base = tests.slot(6)
      top = tests.pt(base.x, base.y, 20.mm)
      tests.add_cylinder(model.entities, base, Z_AXIS, 25.mm, 20.mm, 24)
      tests.explode_circles(model.entities, [base, top])
      wall = tests.walls_at(model.entities, base, 25.mm)
      cylinders, rejected = CircleMaster::Detector.from_faces(wall)
      c.check(cylinders.length == 1 && cylinders.first.loops.all? { |l| l.arc.nil? }, 'broken cylinder detected',
              rejected.inspect)
      next if cylinders.empty?
      change = CircleMaster::VcbParser.parse_size('52')
      started = Time.now
      _count, native, welded = tests.with_mode('diameter') { CircleMaster::Resizer.resize(cylinders, change) }
      c.note(format('%.2fs', Time.now - started))
      c.check(native == 2 && welded.zero?, 'both end circles rebuilt as native', "native #{native}, welded #{welded}")
      ends = [base, top].map { |p| tests.arcs_at(model.entities, p) }
      c.check(ends.all? { |a| a.length == 1 && (a.first.radius - 26.mm).abs < 1e-6 && a.first.count_edges == 24 },
              'native circles of 24 segments, diameter 52 mm',
              ends.map { |a| a.map { |cv| [cv.count_edges, (cv.radius.to_f / 1.mm).round(4)] } }.inspect)
    end
  end
end
