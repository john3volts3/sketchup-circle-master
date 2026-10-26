# encoding: UTF-8
# Comparison of the reconstruction engines (step 5 of DIRECTIVES_BUNDLE.md),
# loaded by run_tests.rb.
#
#   Solid Progress   SolidProcedural::CircleRestore.restore_in_solid, as
#                    installed in this SketchUp (rebuilds every broken
#                    circle of a solid, same size and segment count)
#   Cylinder Resize  CircleMaster::Detector + Rebuilder (cylinders/), as
#                    Resizer.resize does, at the current radii
#   Circle Advanced  CircleMaster::Volume (segment count change): no
#                    counterpart, checked on its own (E9)
#
# Each INFO case builds one broken solid (geometry of the T15 tests of Solid
# Progress), then runs each engine in an operation that is aborted, and
# compares the results (faces, edges, circles, volume, materials) and times.
# The booleans are native in SketchUp Pro, Solid for Maker in Make.

module CircleMasterTests
  # Solid Progress engine available in this SketchUp: its version, or nil.
  def self.sp_version
    return nil unless defined?(SolidProcedural::CircleRestore) &&
                      SolidProcedural::CircleRestore.respond_to?(:restore_in_solid)
    defined?(SolidProcedural::VERSION) ? SolidProcedural::VERSION : '?'
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

  # Cylinder Resize: cylinders found once, then each one with a broken end
  # circle rebuilt at its own radii (as Resizer.resize does). Returns a
  # summary.
  def self.run_cr(solid)
    ents = inner(solid)
    cylinders, _rejected = CircleMaster::Detector.from_faces(ents.grep(Sketchup::Face))
    broken = cylinders.select { |cyl| cyl.loops.any? { |l| l.arc.nil? } }
    rebuilt = 0
    reasons = Hash.new(0)
    broken.each do |cyl|
      reason = CircleMaster::Rebuilder.unsupported_reason(cyl)
      if reason
        reasons[reason] += 1
        next
      end
      CircleMaster::Rebuilder.rebuild(ents, cyl, cyl.loops.map(&:radius))
      rebuilt += 1
    end
    text = "#{cylinders.length} cylinder(s), #{broken.length} broken, #{rebuilt} rebuilt"
    text += " (refused: #{reasons.map { |r, n| "#{r}: #{n}" }.join(', ')})" unless reasons.empty?
    text
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
    y0 = 2000

    # [name, booleans needed?, build(model, x, y) -> [base, [[op, tool], ...]]]
    cases = [
      ['exploded end circles', false, lambda do |m, x, y|
        g = tests.cylinders(m.entities, [tests.pt(x + 5, y + 5, 0)], Z_AXIS, 1, 2)
        tests.explode_circles(g.entities)
        [g, []]
      end],
      # Splitting an edge of a native circle keeps it native: the circles
      # are exploded first, as a boolean leaves them.
      ['exploded end circle with a split point', false, lambda do |m, x, y|
        g = tests.cylinders(m.entities, [tests.pt(x + 5, y + 5, 0)], Z_AXIS, 1, 2)
        tests.explode_circles(g.entities)
        edge = g.entities.grep(Sketchup::Edge).find do |e|
          e.vertices.all? { |v| (v.position.z - 2).abs < 1e-6 } && e.faces.length == 2
        end
        edge.split(0.5)
        [g, []]
      end],
      ['plate with 20 holes', true, lambda do |m, x, y|
        centers = (0...5).flat_map { |i| (0...4).map { |j| tests.pt(x + 4 + 8 * i, y + 4 + 8 * j, -1) } }
        [tests.box(m.entities, x, y, 0, 40, 32, 2),
         [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 0.8, 4)]]]
      end],
      ['holes near an edge', true, lambda do |m, x, y|
        centers = [[1.15, 5], [5, 1.2], [10, 5], [15, 5]].map { |a, b| tests.pt(x + a, y + b, -1) }
        [tests.box(m.entities, x, y, 0, 20, 10, 2),
         [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 1, 4)]]]
      end],
      ['truncated cones', true, lambda do |m, x, y|
        cones = [[5, 5], [15, 5], [5, 15]].map { |a, b| tests.pt(x + a, y + b, -1) }
        [tests.box(m.entities, x, y, 0, 20, 20, 3),
         [['subtract', tests.cones(m.entities, cones, 1.5, 0.7, 5)],
          ['subtract', tests.cylinders(m.entities, [tests.pt(x + 15, y + 15, -1)], Z_AXIS, 1, 5)]]]
      end],
      ['counterbores', true, lambda do |m, x, y|
        holes = [5, 12, 19].map { |a| tests.pt(x + a, y + 5, -1) }
        bores = holes.map { |p| tests.pt(p.x, p.y, 2) }
        [tests.box(m.entities, x, y, 0, 24, 10, 3),
         [['subtract', tests.cylinders(m.entities, bores, Z_AXIS, 2, 2)],
          ['subtract', tests.cylinders(m.entities, holes, Z_AXIS, 1, 5)]]]
      end],
      ['pins added by union (one end broken)', true, lambda do |m, x, y|
        centers = [[5, 5], [15, 5], [5, 15], [15, 15]].map { |a, b| tests.pt(x + a, y + b, 1) }
        [tests.box(m.entities, x, y, 0, 20, 20, 2),
         [['union', tests.cylinders(m.entities, centers, Z_AXIS, 1, 4)]]]
      end],
      ['blind holes', true, lambda do |m, x, y|
        centers = [[5, 5], [15, 5], [5, 15], [15, 15]].map { |a, b| tests.pt(x + a, y + b, 2) }
        [tests.box(m.entities, x, y, 0, 20, 20, 4),
         [['subtract', tests.cylinders(m.entities, centers, Z_AXIS, 1, 3)]]]
      end]
    ]

    cases.each_with_index do |(name, booleans, build), i|
      test "E#{i + 1} Engines: #{name}", info: true do |c, model|
        next c.skip('Solid Progress not installed in this SketchUp') unless tests.sp_version
        next c.skip('no boolean here (SketchUp Pro or Solid for Maker needed)') if booleans && !tests.boolean_engine
        base, steps = build.call(model, x0 + i * 250, y0)
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
        before = tests.shape_signature(acc)
        results = {}
        [[:sp, 'Solid Progress'], [:cr, 'Cylinder Resize']].each do |key, label|
          model.start_operation('Circle Master tests — engine', true)
          begin
            started = Time.now
            text = key == :sp ? tests.run_sp(acc) : tests.run_cr(acc)
            results[key] = { time: Time.now - started, text: text, sig: tests.shape_signature(acc) }
          rescue => e
            results[key] = { error: "#{e.class}: #{e.message}" }
          ensure
            model.abort_operation
          end
          c.check(tests.shape_signature(acc) == before, "#{label}: model restored after the run")
          r = results[key]
          if r[:error]
            c.check(false, "#{label}: no exception", r[:error])
            next
          end
          c.check(r[:sig][:manifold], "#{label}: still a solid")
          c.note(format('%s: %.2fs, %s; native arcs %d -> %d', label, r[:time], r[:text],
                        before[:arcs], r[:sig][:arcs]))
        end
        sp = results[:sp]
        cr = results[:cr]
        same = sp[:sig] && cr[:sig] && sp[:sig] == cr[:sig] ? true : false
        diff = sp[:sig] && cr[:sig] ? tests.signature_diff(sp[:sig], cr[:sig]) : 'an engine failed'
        c.check(same, 'same result (faces, edges, circles, volume, materials)', diff)
        time = ->(r) { r[:time] ? format('%.2fs', r[:time]) : 'error' }
        arcs = ->(r) { r[:sig] ? r[:sig][:arcs].to_s : '-' }
        tests.engine_rows << format('%-40s %s  SP %-7s CR %-7s native arcs: before %d, SP %s, CR %s',
                                    name, same ? 'SAME' : 'DIFF', time.call(sp), time.call(cr),
                                    before[:arcs], arcs.call(sp), arcs.call(cr))
      end
    end

    # E9: segment count change of Circle Advanced (Volume), on its own.
    test 'E9 Circle Advanced engine: cylinder 24 -> 48 segments' do |c, model|
      x = x0 + cases.length * 250
      center = tests.pt(x + 5, y0 + 5, 0)
      top = tests.pt(center.x, center.y, 2)
      g = tests.cylinders(model.entities, [center], Z_AXIS, 1, 2, 24)
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
        CircleMaster::Volume.rebuild(ents, body, 48)
        model.commit_operation
      rescue
        model.abort_operation
        raise
      end
      c.note(format('%.2fs', Time.now - started))
      ends = [center, top].map { |p| tests.arcs_at(ents, p) }
      c.check(ends.all? { |a| a.length == 1 && a.first.count_edges == 48 }, 'both ends: one native circle of 48',
              ends.map { |a| a.map(&:count_edges) }.inspect)
      expected = 48 / 2.0 * Math.sin(2 * Math::PI / 48) * 2
      c.check((g.volume - expected).abs < expected * 1e-4, 'volume of a 48-sided prism',
              "#{g.volume.round(5)} / #{expected.round(5)}")
      c.check(g.manifold?, 'still a solid')
      walls = ents.grep(Sketchup::Face).reject { |f| f.normal.parallel?(Z_AXIS) }
      c.check(walls.length == 48 && walls.all? { |f| f.material == wall_mat }, 'wall: 48 faces, material kept',
              walls.length.to_s)
      tops = ents.grep(Sketchup::Face).select { |f| f.normal.z > 0.99 }
      c.check(tops.length == 1 && tops.first.material == top_mat, 'top face: material kept')
    end

    # E10: radius change of Cylinder Resize on a broken cylinder, through
    # Resizer.resize (active context: the model).
    test 'E10 Cylinder Resize engine: broken cylinder, 50 -> 52 mm' do |c, model|
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
