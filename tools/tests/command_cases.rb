# encoding: UTF-8
# Commands of Circle Master driven as a user would (step 6 of
# DIRECTIVES_BUNDLE.md); loaded by run_tests.rb.
#
# Mouse: a FakeInputPoint stands for Sketchup::InputPoint (the test sets the
# picked point and the face under it), then the tool events are called
# (onMouseMove, onLButtonDown/Up, onLButtonDoubleClick); keys: onKeyDown,
# onKeyUp, onCancel; Cylinder Resize Tool: the face under the cursor is
# given by the test (pick_face). Dialogs: UI.inputbox and UI.messagebox are
# answered by the runner; the Settings window is really opened and filled
# in through JavaScript. SketchUp's own inference engine and what is drawn
# on screen are not tested.
#
# C Circle tool, M modify mode, F rounded corners, K copy mode and
# double-click, R cylinder resizing, X robustness, D dialogs and interface
# (requirements of Circle Advanced 1.4.0 and Cylinder Resize 0.3.0, PRD of
# Circle Master). Lengths in mm.

module CircleMasterTests
  # Stand-in for Sketchup::InputPoint: the picked point is set by the test.
  class FakeInputPoint
    attr_accessor :position, :face

    def pick(*_args)
      true
    end

    def valid?
      !@position.nil?
    end

    def display?
      false
    end

    def tooltip
      ''
    end

    def draw(_view)
      nil
    end

    def transformation
      Geom::Transformation.new
    end

    def copy!(other)
      @position = other.position ? other.position.clone : nil
      @face = other.face
      self
    end

    def degrees_of_freedom
      3
    end

    def edge
      nil
    end

    def vertex
      nil
    end
  end

  # --- Driving the tools -------------------------------------------------------

  def self.view
    Sketchup.active_model.active_view
  end

  def self.select(model, *entities)
    model.selection.clear
    model.selection.add(entities.flatten)
  end

  # Circle tool driven by the test: [tool, input point].
  def self.circle_tool(model)
    tool = CircleMaster::CircleTool.new
    model.select_tool(tool)
    ip = FakeInputPoint.new
    tool.instance_variable_set(:@ip, ip)
    tool.instance_variable_set(:@ip_center, FakeInputPoint.new)
    [tool, ip]
  end

  # Mouse over +point+ (+face+ under it), at screen x = +x+.
  def self.move(tool, ip, point, face = nil, x = 100)
    ip.position = point
    ip.face = face
    tool.onMouseMove(0, x, 100, view)
  end

  # Press and release at the same place over +point+.
  def self.click(tool, ip, point, face = nil, flags = 0)
    move(tool, ip, point, face)
    tool.onLButtonDown(flags, 100, 100, view)
    tool.onLButtonUp(flags, 100, 100, view)
  end

  # Circle by click-click: center, then a point at +radius+ along +dir+.
  def self.click_circle(tool, ip, center, radius, dir = X_AXIS, face = nil)
    click(tool, ip, center, face)
    click(tool, ip, center.offset(dir, radius), face)
  end

  def self.ctrl_tap(tool)
    tool.onKeyDown(COPY_MODIFIER_KEY, false, 0, view)
    tool.onKeyUp(COPY_MODIFIER_KEY, false, 0, view)
  end

  # Cylinder Resize Tool on the cylinders whose wall is selected.
  def self.resize_tool(model)
    tool = CircleMaster::ResizeTool.new
    model.select_tool(tool)
    tool
  end

  def self.mm_of(length)
    (length.to_f / 1.mm).round(4)
  end

  # [[radius in mm, segment count], ...] of the native circles centered at
  # each point.
  def self.circles_at(entities, *centers)
    centers.map { |p| arcs_at(entities, p).map { |cv| [mm_of(cv.radius), cv.count_edges] } }
  end

  # --- Geometry (in +entities+, not grouped) -----------------------------------

  # Block of w x d x h with its base corner at +o+. Returns its top face.
  def self.add_block(entities, o, w, d, h)
    f = entities.add_face(o, o.offset(X_AXIS, w), o.offset(X_AXIS, w).offset(Y_AXIS, d), o.offset(Y_AXIS, d))
    f.reverse! if f.normal.z < 0
    f.pushpull(h)
    inside = pt(o.x + w / 4.0, o.y + d / 4.0, o.z + h)
    entities.grep(Sketchup::Face).find do |face|
      face.normal.z > 0.99 && face.classify_point(inside) == Sketchup::Face::PointInside
    end
  end

  # Native circle of radius +r+ on the face at +center+, pushed by +depth+
  # (negative: hole, positive: pin).
  def self.push_circle(entities, center, r, depth, segments = 24)
    edges = entities.add_circle(center, Z_AXIS, r, segments)
    disc = edges.first.faces.find { |f| f.outer_loop.edges.all? { |e| edges.include?(e) } }
    disc.pushpull(depth)
  end

  # Truncated cone along +z: radius r1 at +center+, r2 at h.
  def self.add_cone(entities, center, r1, r2, h, segments = 24)
    add_cylinder(entities, center, Z_AXIS, r1, h, segments)
    top = pt(center.x, center.y, center.z + h)
    ring = arcs_at(entities, top).first.edges
    entities.transform_entities(Geom::Transformation.scaling(top, r2 / r1), ring)
  end

  # Block of l x l x h whose corner (l, l) is rounded with radius r (outer
  # rounded corner). Returns the center of the bottom arc.
  def self.add_rounded_block(entities, o, l, r, h, segments = 12)
    p = ->(x, y) { pt(o.x + x, o.y + y, o.z) }
    c = p.call(l - r, l - r)
    entities.add_line(p.call(0, 0), p.call(l, 0))
    entities.add_line(p.call(l, 0), p.call(l, l - r))
    entities.add_arc(c, X_AXIS, Z_AXIS, r, 0, Math::PI / 2, segments)
    entities.add_line(p.call(l - r, l), p.call(0, l))
    close_and_push(entities, entities.add_line(p.call(0, l), p.call(0, 0)), h)
    c
  end

  # L-shaped block (2l x 2l, notch l x l) whose inner corner (l, l) is
  # rounded with radius r (inner rounded corner). Returns the center of the
  # bottom arc.
  def self.add_rounded_l(entities, o, l, r, h, segments = 12)
    p = ->(x, y) { pt(o.x + x, o.y + y, o.z) }
    c = p.call(l + r, l + r)
    [p.call(0, 0), p.call(2 * l, 0), p.call(2 * l, l), p.call(l + r, l)].each_cons(2) do |a, b|
      entities.add_line(a, b)
    end
    entities.add_arc(c, X_AXIS.reverse, Z_AXIS, r, 0, Math::PI / 2, segments)
    entities.add_line(p.call(l, l + r), p.call(l, 2 * l))
    entities.add_line(p.call(l, 2 * l), p.call(0, 2 * l))
    close_and_push(entities, entities.add_line(p.call(0, 2 * l), p.call(0, 0)), h)
    c
  end

  def self.close_and_push(_entities, edge, h)
    edge.find_faces
    face = edge.faces.first
    face.reverse! if face.normal.z < 0
    face.pushpull(h)
  end

  # Edges whose two vertices lie on the vertical line through (x, y).
  def self.vertical_edges_at(entities, x, y)
    entities.grep(Sketchup::Edge).count do |e|
      e.vertices.all? do |v|
        q = v.position
        (q.x.to_f - x.to_f).abs < 1e-6 && (q.y.to_f - y.to_f).abs < 1e-6
      end
    end
  end

  # Smallest and largest horizontal distance (mm) of the vertices of +faces+
  # to the vertical axis through +base+.
  def self.radius_range(faces, base)
    d = faces.flat_map(&:vertices).uniq.map do |v|
      q = v.position
      Math.hypot(q.x.to_f - base.x.to_f, q.y.to_f - base.y.to_f) / 1.mm.to_f
    end
    [d.min.round(4), d.max.round(4)]
  end

  # Upward faces at height +z+ containing +point+ (projected).
  def self.up_faces_at(entities, point, z)
    p = pt(point.x, point.y, z)
    entities.grep(Sketchup::Face).select do |f|
      f.normal.z > 0.99 && f.classify_point(p) == Sketchup::Face::PointInside
    end
  end

  # Horizontal faces (up or down: a face drawn on the ground faces down)
  # containing +point+.
  def self.flat_faces_at(entities, point)
    entities.grep(Sketchup::Face).select do |f|
      f.normal.parallel?(Z_AXIS) && f.classify_point(point) == Sketchup::Face::PointInside
    end
  end

  # Diagnosis of a refused rounded corner: each condition of Fillet.check is
  # recorded (lines returned) before the plugin's own check runs, unchanged.
  # unwatch_fillet_check afterwards.
  def self.watch_fillet_check
    fillet = CircleMaster::Fillet
    single = fillet.singleton_class
    single.send(:alias_method, :cm_tests_check, :check) unless single.method_defined?(:cm_tests_check)
    lines = []
    fillet.define_singleton_method(:check) do |arcs, centers, normal, n, end_edges, cap_props, empty_side|
      found = arcs.map do |edges|
        cv = edges.first && edges.first.valid? ? edges.first.curve : nil
        [edges.size, cv ? cv.class.name.split('::').last : nil, cv.respond_to?(:count_edges) ? cv.count_edges : nil]
      end
      lines << "arcs (edges, curve, count): #{found.inspect}"
      lines << "edges at the tangent points: #{end_edges.map(&:size).inspect} (want [1, 1])"
      walls = arcs[0].flat_map(&:faces).uniq.count { |f| !f.normal.parallel?(normal) }
      lines << "wall faces on arc 0: #{walls} (want #{n})"
      arcs.each_with_index do |edges, k|
        sides = edges.flat_map do |e|
          e.faces.select { |f| f.normal.parallel?(normal) }
                 .map { |f| CircleMaster::Resegmenter.side_of(f, e, centers[k]) }
        end
        lines << "arc #{k}: cap face sides #{sides.uniq.inspect}, empty side #{empty_side.inspect}, " \
                 "cap expected #{cap_props[k] ? 'yes' : 'no'}"
      end
      fillet.cm_tests_check(arcs, centers, normal, n, end_edges, cap_props, empty_side)
    end
    # Every Resegmenter.side_of call (chord length, face, result).
    reseg = CircleMaster::Resegmenter
    rsingle = reseg.singleton_class
    rsingle.send(:alias_method, :cm_tests_side_of, :side_of) unless rsingle.method_defined?(:cm_tests_side_of)
    reseg.define_singleton_method(:side_of) do |face, edge, center|
      side = reseg.cm_tests_side_of(face, edge, center)
      len = edge.start.position.distance(edge.end.position).to_f / 1.mm.to_f
      lines << format('side_of: chord %.4f mm, face of %d edges (area %.2f mm2) -> %s',
                      len, face.edges.length, face.area / 1.mm.to_f**2, side.inspect)
      side
    end
    lines
  end

  def self.unwatch_fillet_check
    single = CircleMaster::Fillet.singleton_class
    single.send(:alias_method, :check, :cm_tests_check) if single.method_defined?(:cm_tests_check)
    rsingle = CircleMaster::Resegmenter.singleton_class
    rsingle.send(:alias_method, :side_of, :cm_tests_side_of) if rsingle.method_defined?(:cm_tests_side_of)
  end

  # Notes the last status text and message box of the plugin (diagnosis of
  # a refusal).
  def self.note_feedback(c)
    c.note("status: #{status.last}") unless status.empty?
    c.note("message: #{messages.last}") unless messages.empty?
  end

  def self.define_command_tests
    tests = self

    # --- Circle tool (EF-01 to EF-08 of Circle Advanced) -------------------

    test 'C1 Circle: click-click, 48 segments, the tool stays usable' do |c, model|
      center = tests.slot(7)
      tool, ip = tests.circle_tool(model)
      tests.click_circle(tool, ip, center, 25.mm)
      got = tests.circles_at(model.entities, center)
      c.check(got == [[[25.0, 48]]], 'native circle, radius 25 mm, 48 segments', got.inspect)
      c.check(!tests.flat_faces_at(model.entities, center).empty?, 'with its face')
      if model.tools.respond_to?(:active_tool)
        c.check(model.tools.active_tool == tool, 'the tool is still the active tool')
      end
      second = center.offset(X_AXIS, 100.mm)
      tests.click_circle(tool, ip, second, 10.mm)
      c.check(tests.circles_at(model.entities, second) == [[[10.0, 48]]], 'a second circle with the same tool')
    end

    test 'C2 Circle: click-drag-release; a short drag does not commit' do |c, model|
      center = tests.slot(8)
      tool, ip = tests.circle_tool(model)
      v = tests.view
      tests.move(tool, ip, center)
      tool.onLButtonDown(0, 100, 100, v)
      tests.move(tool, ip, center.offset(X_AXIS, 20.mm), nil, 200)
      tool.onLButtonUp(0, 200, 100, v)
      got = tests.circles_at(model.entities, center)
      c.check(got == [[[20.0, 48]]], 'released 100 px away: circle of radius 20 mm', got.inspect)
      other = center.offset(X_AXIS, 100.mm)
      tests.move(tool, ip, other)
      tool.onLButtonDown(0, 100, 100, v)
      tests.move(tool, ip, other.offset(X_AXIS, 20.mm), nil, 102)
      tool.onLButtonUp(0, 102, 100, v)
      c.check(tests.circles_at(model.entities, other) == [[]], 'released 2 px away: no circle yet')
      tool.onCancel(0, v)
    end

    test 'C3 Circle: Esc cancels the circle in progress' do |c, model|
      center = tests.slot(9)
      tool, ip = tests.circle_tool(model)
      v = tests.view
      tests.click(tool, ip, center)
      tool.onCancel(0, v)
      edge_point = center.offset(X_AXIS, 20.mm)
      tests.click(tool, ip, edge_point) # a new center, not the radius
      tool.onCancel(0, v)
      got = tests.circles_at(model.entities, center, edge_point)
      c.check(got == [[], []], 'no circle created', got.inspect)
      c.check(tool.instance_variable_get(:@state) == CircleMaster::CircleTool::STATE_CENTER, 'back to picking a center')
    end

    test 'C4 Circle: typed 50, 25r, d50, 50;36s; an integer alone sets the sides' do |c, model|
      tool, ip = tests.circle_tool(model)
      v = tests.view
      tool.onUserText('24', v)
      c.check(CircleMaster::Settings.segments == 24 && tests.vcb[:label] == 'Sides' && tests.vcb[:value] == '24',
              '24 alone before the first click: 24 sides', "#{CircleMaster::Settings.segments}, #{tests.vcb.inspect}")
      c.check(tests.writes.last == 'CircleMaster/segments', 'remembered in CircleMaster (intercepted)')
      CircleMaster::Settings.instance_variable_set(:@segments, 48)
      base = tests.slot(10)
      [['50', 25.0, 48], ['25r', 25.0, 48], ['d50', 25.0, 48], ['50;36s', 25.0, 36]].each_with_index do |(text, r, n), i|
        center = base.offset(Y_AXIS, i * 100.mm)
        tests.click(tool, ip, center)
        tool.onUserText(text, v)
        got = tests.circles_at(model.entities, center)
        c.check(got == [[[r, n]]], "#{text}: radius #{r} mm, #{n} segments", got.inspect)
      end
      c.check(CircleMaster::Settings.segments == 36, '36 segments remembered after 50;36s')
    end

    test 'C5 Circle: just after a circle, 60, +5 and 36s change it' do |c, model|
      center = tests.slot(11)
      tool, ip = tests.circle_tool(model)
      v = tests.view
      tests.click(tool, ip, center)
      tool.onUserText('50', v)
      [['60', [[[30.0, 48]]]], ['+5', [[[32.5, 48]]]], ['36s', [[[32.5, 36]]]]].each do |text, want|
        tool.onUserText(text, v)
        got = tests.circles_at(model.entities, center)
        c.check(got == want, "#{text}: #{want.inspect} (one circle, changed)", got.inspect)
      end
    end

    test 'C6 Circle: normal of the hovered face, arrow and Shift locks, preview colors' do |c, model|
      base = tests.slot(12)
      wall = model.entities.add_face(base, base.offset(Y_AXIS, 100.mm),
                                     base.offset(Y_AXIS, 100.mm).offset(Z_AXIS, 100.mm), base.offset(Z_AXIS, 100.mm))
      tool, ip = tests.circle_tool(model)
      v = tests.view
      p1 = base.offset(X_AXIS, 200.mm)
      tests.click_circle(tool, ip, p1, 20.mm, Y_AXIS, wall)
      cv = tests.arcs_at(model.entities, p1).first
      c.check(cv && cv.normal.parallel?(X_AXIS), 'over a vertical face: circle on that face orientation')
      p2 = base.offset(X_AXIS, 400.mm)
      tool.onKeyDown(VK_RIGHT, false, 0, v)
      tests.click_circle(tool, ip, p2, 20.mm, Y_AXIS)
      cv = tests.arcs_at(model.entities, p2).first
      c.check(cv && cv.normal.parallel?(X_AXIS), 'right arrow: normal locked on the red axis')
      p3 = base.offset(X_AXIS, 600.mm)
      tests.move(tool, ip, p3)
      tool.onKeyDown(CONSTRAIN_MODIFIER_KEY, false, 0, v)
      tests.click_circle(tool, ip, p3, 20.mm, X_AXIS, wall)
      tool.onKeyUp(CONSTRAIN_MODIFIER_KEY, false, 0, v)
      cv = tests.arcs_at(model.entities, p3).first
      c.check(cv && cv.normal.parallel?(Z_AXIS), 'Shift held: orientation kept over the vertical face')
      colors = [X_AXIS, Y_AXIS, Z_AXIS, Geom::Vector3d.new(1, 1, 0)].map { |n| tool.send(:color_for, n) }
      klass = CircleMaster::CircleTool
      c.check(colors == [klass::COLOR_X, klass::COLOR_Y, klass::COLOR_Z, klass::COLOR_OTHER],
              'preview colors: red, green, blue along the axes, black otherwise')
    end

    test 'C7 Circle: drawn in an open group, where it was clicked' do |c, model|
      next c.skip('opening a group needs SketchUp 2020.1+ (Model#active_path=)') unless tests.open_path?(model)
      base = tests.slot(13)
      g = model.entities.add_group
      g.entities.add_cpoint(ORIGIN)
      g.transformation = Geom::Transformation.translation(base.offset(Y_AXIS, 300.mm) - ORIGIN) *
                         Geom::Transformation.rotation(ORIGIN, Z_AXIS, 30.degrees)
      model.active_path = [g]
      world = base.offset(X_AXIS, 100.mm)
      tool, ip = tests.circle_tool(model)
      tests.click_circle(tool, ip, world, 20.mm)
      model.select_tool(nil)
      tests.close_all(model)
      cv = g.entities.grep(Sketchup::Edge).map(&:curve).compact.uniq.find { |x| x.is_a?(Sketchup::ArcCurve) }
      at = cv ? cv.center.transform(g.transformation) : nil
      c.check(cv && at.distance(world).to_f < 1e-4, 'in the group, centered where clicked',
              at ? "#{at.distance(world).to_f / 1.mm.to_f} mm away" : 'no circle in the group')
      c.check(cv && tests.mm_of(cv.radius) == 20.0, 'radius 20 mm')
    end

    # --- Modify mode (EF-12 to EF-19) -----------------------------------------

    test 'M1 Modify mode: the Measurements box shows the size (circle, arc)' do |c, model|
      center = tests.slot(14)
      edges = model.entities.add_circle(center, Z_AXIS, 25.mm, 48)
      edges.first.find_faces
      tests.select(model, edges)
      tests.circle_tool(model)
      want = "#{Sketchup.format_length(50.mm)}; 48s"
      c.check(tests.vcb[:label] == 'Diameter; Segments' && tests.vcb[:value] == want,
              "circle: Diameter; Segments = #{want}", tests.vcb.inspect)
      model.select_tool(nil)
      arc = model.entities.add_arc(center.offset(X_AXIS, 200.mm), X_AXIS, Z_AXIS, 20.mm, 0, Math::PI / 2, 12)
      tests.select(model, arc)
      tests.circle_tool(model)
      want = "#{Sketchup.format_length(40.mm)}; 12s"
      c.check(tests.vcb[:label] == 'Diameter; Segments' && tests.vcb[:value] == want,
              "arc: Diameter; Segments = #{want}", tests.vcb.inspect)
    end

    test 'M2 Modify mode: 70, 30r, d80 resize the selected circle' do |c, model|
      center = tests.slot(15)
      edges = model.entities.add_circle(center, Z_AXIS, 25.mm, 48)
      edges.first.find_faces
      tests.select(model, edges)
      tool, _ip = tests.circle_tool(model)
      [['70', 35.0], ['30r', 30.0], ['d80', 40.0]].each do |text, r|
        tool.onUserText(text, tests.view)
        got = tests.circles_at(model.entities, center)
        c.check(got == [[[r, 48]]], "#{text}: radius #{r} mm", got.inspect)
      end
    end

    test 'M3 Modify mode: increments +1, -0,5, +r1, --1' do |c, model|
      center = tests.slot(16)
      edges = model.entities.add_circle(center, Z_AXIS, 25.mm, 48)
      edges.first.find_faces
      tests.select(model, edges)
      tool, _ip = tests.circle_tool(model)
      [['+1', 25.5], ['-0,5', 25.25], ['+r1', 26.25], ['--1', 26.75]].each do |text, r|
        tool.onUserText(text, tests.view)
        got = tests.circles_at(model.entities, center)
        c.check(got == [[[r, 48]]], "#{text}: radius #{r} mm", got.inspect)
      end
    end

    test 'M4 Modify mode: several circles, each by its own size; Esc leaves the mode' do |c, model|
      a = tests.slot(17)
      b = a.offset(X_AXIS, 200.mm)
      ea = model.entities.add_circle(a, Z_AXIS, 25.mm, 48)
      eb = model.entities.add_circle(b, Z_AXIS, 15.mm, 24)
      tests.select(model, ea, eb)
      tool, _ip = tests.circle_tool(model)
      tool.onUserText('+10', tests.view)
      got = tests.circles_at(model.entities, a, b)
      c.check(got == [[[30.0, 48]], [[20.0, 24]]], '+10: radii 30 and 20 mm', got.inspect)
      c.check(tool.send(:modifying?), 'still in modify mode')
      tool.onCancel(0, tests.view)
      c.check(!tool.send(:modifying?) && model.selection.empty?, 'Esc: mode left, selection cleared')
    end

    test 'M5 Modify mode: 36s on a circle and on an arc; 60;36s; default unchanged' do |c, model|
      center = tests.slot(18)
      edges = model.entities.add_circle(center, Z_AXIS, 25.mm, 48)
      edges.first.find_faces
      tests.select(model, edges)
      tool, _ip = tests.circle_tool(model)
      writes = tests.writes.length
      tool.onUserText('36s', tests.view)
      got = tests.circles_at(model.entities, center)
      c.check(got == [[[25.0, 36]]], 'circle: 36 segments', got.inspect)
      tool.onUserText('60;36s', tests.view)
      got = tests.circles_at(model.entities, center)
      c.check(got == [[[30.0, 36]]], '60;36s: radius 30 mm, 36 segments', got.inspect)
      model.select_tool(nil)
      ac = center.offset(X_AXIS, 200.mm)
      arc = model.entities.add_arc(ac, X_AXIS, Z_AXIS, 20.mm, 0, Math::PI / 2, 12)
      tests.select(model, arc)
      tool, _ip = tests.circle_tool(model)
      tool.onUserText('36s', tests.view)
      cv = tests.arcs_at(model.entities, ac).first
      sweep = cv ? cv.end_angle - cv.start_angle : 0
      c.check(cv && cv.count_edges == 36 && tests.mm_of(cv.radius) == 20.0 && (sweep - Math::PI / 2).abs < 1e-6,
              'arc: 36 segments, same radius and angle', cv ? [cv.count_edges, tests.mm_of(cv.radius), sweep].inspect : 'no arc')
      c.check(CircleMaster::Settings.segments == 48 && tests.writes.length == writes,
              'default segment count unchanged, nothing remembered')
    end

    test 'M6 Modify mode: both end circles of a cylinder selected, 36s' do |c, model|
      base = tests.slot(19)
      top = tests.pt(base.x, base.y, 30.mm)
      tests.add_cylinder(model.entities, base, Z_AXIS, 20.mm, 30.mm, 24)
      ends = [base, top].map { |p| tests.arcs_at(model.entities, p).first }
      tests.select(model, ends.map(&:edges))
      tool, _ip = tests.circle_tool(model)
      tool.onUserText('36s', tests.view)
      got = tests.circles_at(model.entities, base, top)
      c.check(got == [[[20.0, 36]], [[20.0, 36]]], 'both ends: 36 segments', got.inspect)
    end

    # --- Rounded corners (EF-20) ------------------------------------------------

    outer = ->(l, r) { [[l, l - r], [l - r, l]] }
    inner = ->(l, r) { [[l, l + r], [l + r, l]] }
    # [name, builder, tangent points, slot, radius, new segment count]
    [['F1 Rounded corner, outer', :add_rounded_block, outer, 20, 10.mm, 24],
     ['F2 Rounded corner, inner', :add_rounded_l, inner, 21, 10.mm, 24],
     ['F3 Small rounded corner, outer (radius 2 mm)', :add_rounded_block, outer, 34, 2.mm, 48]].each do |name, builder, tangents, k, r, n_new|
      test "#{name}: 12 -> #{n_new} segments" do |c, model|
        o = tests.slot(k)
        l = 40.mm
        h = 20.mm
        rm = tests.mm_of(r)
        center = tests.send(builder, model.entities, o, l, r, h)
        top = tests.pt(center.x, center.y, center.z + h)
        arc = tests.arcs_at(model.entities, top).first
        next c.check(false, 'rounded corner built') unless arc
        tests.select(model, arc.edges)
        tool, _ip = tests.circle_tool(model)
        tests.status.clear
        tests.messages.clear
        diag = tests.watch_fillet_check
        begin
          tool.onUserText("#{n_new}s", tests.view)
        ensure
          tests.unwatch_fillet_check
        end
        got = tests.circles_at(model.entities, center, top)
        ok = c.check(got == [[[rm, n_new]], [[rm, n_new]]], "both arcs: native, radius #{rm} mm, #{n_new} segments",
                     got.inspect)
        unless ok
          tests.note_feedback(c)
          diag.each { |line| c.note("Fillet.check: #{line}") }
        end
        tangents.call(l, r).each do |x, y|
          n = tests.vertical_edges_at(model.entities, o.x + x, o.y + y)
          c.check(n == 1, "one edge at the tangent point (#{tests.mm_of(x)}, #{tests.mm_of(y)})", n.to_s)
        end
      end
    end

    # --- Copy mode and double-click (EF-21, EF-22) ---------------------------

    test 'K1 Copy mode: Ctrl copies the selected circle, each click places one; = and Esc' do |c, model|
      base = tests.slot(22)
      edges = model.entities.add_circle(base, Z_AXIS, 20.mm, 24)
      edges.first.find_faces
      tests.select(model, edges)
      tool, ip = tests.circle_tool(model)
      tests.ctrl_tap(tool)
      c.check(!tool.instance_variable_get(:@template).nil?, 'Ctrl alone: copy mode on')
      p1 = base.offset(X_AXIS, 100.mm)
      p2 = base.offset(X_AXIS, 200.mm)
      tests.click(tool, ip, p1)
      tests.click(tool, ip, p2)
      got = tests.circles_at(model.entities, p1, p2)
      c.check(got == [[[20.0, 24]], [[20.0, 24]]], 'two clicks: two circles of radius 20 mm, 24 segments', got.inspect)
      tests.ctrl_tap(tool)
      c.check(tool.instance_variable_get(:@template).nil?, 'Ctrl again: copy mode off')
      model.select_tool(nil)
      tests.select(model, edges)
      tool, _ip = tests.circle_tool(model)
      tool.onUserText('=', tests.view)
      c.check(!tool.instance_variable_get(:@template).nil?, '= typed: copy mode on')
      tool.onCancel(0, tests.view)
      c.check(tool.instance_variable_get(:@template).nil?, 'Esc: copy mode off')
    end

    test 'K2 Double-click: a circle like the previous one; ignored in copy mode' do |c, model|
      CircleMaster::CircleTool.previous = { radius: 15.mm.to_f, segments: 30 }
      p = tests.slot(23)
      tool, ip = tests.circle_tool(model)
      v = tests.view
      tests.move(tool, ip, p)
      tool.onLButtonDown(0, 100, 100, v)
      tool.onLButtonUp(0, 100, 100, v)
      tool.onLButtonDoubleClick(0, 100, 100, v)
      tool.onLButtonUp(0, 100, 100, v)
      got = tests.circles_at(model.entities, p)
      c.check(got == [[[15.0, 30]]], 'circle of the previous size and segments, at the click', got.inspect)
      model.select_tool(nil)
      model_circle = p.offset(Y_AXIS, 200.mm)
      edges = model.entities.add_circle(model_circle, Z_AXIS, 10.mm, 12)
      tests.select(model, edges)
      tool, ip = tests.circle_tool(model)
      tool.onUserText('=', v)
      p2 = p.offset(X_AXIS, 200.mm)
      tests.move(tool, ip, p2)
      tool.onLButtonDown(0, 100, 100, v)
      tool.onLButtonUp(0, 100, 100, v)
      tool.onLButtonDoubleClick(0, 100, 100, v)
      tool.onLButtonUp(0, 100, 100, v)
      got = tests.circles_at(model.entities, p2)
      c.check(got == [[[10.0, 12]]], 'copy mode: one circle only, the copied one', got.inspect)
    end

    # --- Cylinder resizing (EF-02 to EF-06 of Circle Master) ----------------

    test 'R1 Resize Cylinders dialog: 5,2 then +0,2, one undo step; Radius mode' do |c, model|
      base = tests.slot(24)
      top = tests.pt(base.x, base.y, 10.mm)
      tests.add_cylinder(model.entities, base, Z_AXIS, 2.5.mm, 10.mm, 24)
      tests.select(model, tests.walls_at(model.entities, base, 2.5.mm))
      tests.inputs << %w[Diameter 5,2]
      CircleMaster.resize_selection
      got = tests.circles_at(model.entities, base, top)
      c.check(got == [[[2.6, 24]], [[2.6, 24]]], 'diameter 5 -> 5,2: both ends native, exact', got.inspect)
      c.later do
        Sketchup.undo
        got = tests.circles_at(model.entities, base, top)
        c.check(got == [[[2.5, 24]], [[2.5, 24]]], 'one undo step: diameter 5 again', got.inspect)
        tests.select(model, tests.walls_at(model.entities, base, 2.5.mm))
        tests.inputs << %w[Diameter +0,2]
        CircleMaster.resize_selection
        got = tests.circles_at(model.entities, base, top)
        c.check(got == [[[2.6, 24]], [[2.6, 24]]], '+0,2: diameter 5,2', got.inspect)
        tests.select(model, tests.walls_at(model.entities, base, 2.6.mm))
        tests.inputs << %w[Radius 3]
        CircleMaster.resize_selection
        got = tests.circles_at(model.entities, base, top)
        c.check(got == [[[3.0, 24]], [[3.0, 24]]], 'Mode Radius, 3: radius 3 mm', got.inspect)
        c.check(CircleMaster::Settings.input_mode == 'radius' && tests.writes.include?('CircleMaster/input_mode'),
                'the dialog mode is the common setting (CircleMaster, intercepted)')
      end
    end

    test 'R2 Cylinder Resize Tool: hover, click, Shift+click, click outside; 15, r10, +1, --1' do |c, model|
      a = tests.slot(25)
      b = a.offset(X_AXIS, 200.mm)
      [a, b].each { |p| tests.add_cylinder(model.entities, p, Z_AXIS, 25.mm, 20.mm, 24) }
      fa = tests.walls_at(model.entities, a, 25.mm).first
      fb = tests.walls_at(model.entities, b, 25.mm).first
      tool = tests.resize_tool(model)
      under = [nil]
      tool.define_singleton_method(:pick_face) { |*_args| under[0] }
      v = tests.view
      count = -> { tool.instance_variable_get(:@targets).length }
      pick = lambda do |face, flags|
        under[0] = face
        tool.onMouseMove(0, 100, 100, v)
        tool.onLButtonDown(flags, 100, 100, v)
      end
      under[0] = fa
      tool.onMouseMove(0, 100, 100, v)
      c.check(!tool.instance_variable_get(:@hover).nil?, 'hover: cylinder found under the cursor')
      pick.call(fa, 0)
      c.check(count.call == 1, 'click: 1 cylinder')
      pick.call(fb, CONSTRAIN_MODIFIER_MASK)
      c.check(count.call == 2, 'Shift+click: 2 cylinders')
      pick.call(fb, CONSTRAIN_MODIFIER_MASK)
      c.check(count.call == 1, 'Shift+click again: back to 1')
      pick.call(nil, 0)
      c.check(count.call.zero?, 'click outside: none')
      pick.call(fa, 0)
      top = tests.pt(a.x, a.y, 20.mm)
      [['15', 7.5], ['r10', 10.0], ['+1', 10.5], ['--1', 11.0]].each do |text, r|
        tool.onUserText(text, v)
        got = tests.circles_at(model.entities, a, top)
        c.check(got == [[[r, 24]], [[r, 24]]], "#{text}: radius #{r} mm", got.inspect)
      end
    end

    test 'R3 Truncated cone: value with No, with Yes (cylinder); increment keeps the angle' do |c, model|
      base = tests.slot(26)
      top = tests.pt(base.x, base.y, 30.mm)
      tests.add_cone(model.entities, base, 15.mm, 7.mm, 30.mm)
      tests.select(model, tests.walls_at(model.entities, base, 15.mm))
      tool = tests.resize_tool(model)
      v = tests.view
      tests.answers << IDNO
      tool.onUserText('20', v)
      got = tests.circles_at(model.entities, base, top)
      c.check(got == [[[15.0, 24]], [[7.0, 24]]], 'No: the cone is unchanged', got.inspect)
      tests.answers << IDYES
      tool.onUserText('20', v)
      got = tests.circles_at(model.entities, base, top)
      c.check(got == [[[10.0, 24]], [[10.0, 24]]], 'Yes: cylinder of diameter 20', got.inspect)
      model.select_tool(nil)
      base2 = base.offset(X_AXIS, 200.mm)
      top2 = tests.pt(base2.x, base2.y, 30.mm)
      tests.add_cone(model.entities, base2, 15.mm, 7.mm, 30.mm)
      tests.select(model, tests.walls_at(model.entities, base2, 15.mm))
      tool = tests.resize_tool(model)
      tool.onUserText('+2', v)
      got = tests.circles_at(model.entities, base2, top2)
      c.check(got == [[[16.0, 24]], [[8.0, 24]]], '+2: both ends +1 mm in radius (same angle), no question',
              got.inspect)
    end

    test 'R4 Block: through hole, pin and blind hole; host face and materials kept' do |c, model|
      o = tests.slot(27)
      red = tests.material(model, 'CM Test Red', [220, 60, 60])
      green = tests.material(model, 'CM Test Green', [60, 200, 60])
      top_face = tests.add_block(model.entities, o, 300.mm, 100.mm, 20.mm)
      top_face.material = red
      hole = tests.pt(o.x + 50.mm, o.y + 50.mm, 20.mm)
      pin = tests.pt(o.x + 150.mm, o.y + 50.mm, 20.mm)
      blind = tests.pt(o.x + 250.mm, o.y + 50.mm, 20.mm)
      tests.push_circle(model.entities, hole, 10.mm, -20.mm)
      tests.push_circle(model.entities, pin, 8.mm, 15.mm)
      tests.push_circle(model.entities, blind, 6.mm, -10.mm)
      tests.up_faces_at(model.entities, blind, 10.mm).each { |f| f.material = green }
      [[hole, 10.mm, '22', 11.0, [hole, tests.pt(hole.x, hole.y, 0)]],
       [pin, 8.mm, '18', 9.0, [pin, tests.pt(pin.x, pin.y, 35.mm)]],
       [blind, 6.mm, '14', 7.0, [blind, tests.pt(blind.x, blind.y, 10.mm)]]].each do |center, r, text, want, ends|
        bottom = tests.pt(center.x, center.y, 0)
        tests.select(model, tests.walls_at(model.entities, bottom, r))
        tool = tests.resize_tool(model)
        tool.onUserText(text, tests.view)
        model.select_tool(nil)
        got = tests.circles_at(model.entities, *ends)
        c.check(got == [[[want, 24]], [[want, 24]]], "#{text}: radius #{want} mm, native", got.inspect)
      end
      hosts = tests.up_faces_at(model.entities, tests.pt(o.x + 5.mm, o.y + 5.mm, 0), 20.mm)
      c.check(hosts.length == 1 && hosts.first.material == red, 'top face: one face, still red')
      bottoms = tests.up_faces_at(model.entities, blind, 10.mm)
      c.check(bottoms.length == 1 && bottoms.first.material == green, 'blind hole bottom: still green')
    end

    test 'R5 Hole cut by a boolean: resized and rebuilt as native circles' do |c, model|
      next c.skip('no boolean here (SketchUp Pro or Solid for Maker needed)') unless tests.boolean_engine
      o = tests.slot(28)
      base = tests.box(model.entities, o.x, o.y, 0, 100.mm, 100.mm, 20.mm)
      center = tests.pt(o.x + 50.mm, o.y + 50.mm, 0)
      cutter = tests.cylinders(model.entities, [tests.pt(center.x, center.y, -10.mm)], Z_AXIS, 10.mm, 40.mm)
      definitions = model.definitions.to_a
      acc = tests.boolean('subtract', base, cutter)
      temp = (model.definitions.to_a - definitions).select { |d| !d.group? && d.count_instances.zero? }
      temp.each { |d| model.definitions.remove(d) } if model.definitions.respond_to?(:remove)
      next c.check(false, "boolean failed (#{tests.boolean_engine})") unless acc && acc.valid?
      c.note("boolean: #{tests.boolean_engine}")
      acc.explode
      wall = tests.walls_at(model.entities, center, 10.mm)
      cylinders, _rejected = CircleMaster::Detector.from_faces(wall)
      c.check(cylinders.length == 1 && cylinders.first.loops.any? { |l| l.arc.nil? }, 'circles broken by the boolean')
      tests.select(model, wall)
      tool = tests.resize_tool(model)
      tool.onUserText('+0,2', tests.view)
      top = tests.pt(center.x, center.y, 20.mm)
      got = tests.circles_at(model.entities, center, top)
      c.check(got == [[[10.1, 24]], [[10.1, 24]]], '+0,2: radius 10,1 mm, native circles', got.inspect)
      c.check(tests.up_faces_at(model.entities, tests.pt(o.x + 5.mm, o.y + 5.mm, 0), 20.mm).length == 1,
              'top face: one face')
      model.select_tool(nil)
      tests.select(model, tests.walls_at(model.entities, center, 10.1.mm))
      tool = tests.resize_tool(model)
      tool.onUserText('48s', tests.view)
      got = tests.circles_at(model.entities, center, top)
      c.check(got == [[[10.1, 48]], [[10.1, 48]]], '48s: 48 segments, same size (EF-12)', got.inspect)
    end

    test 'R6 Circle not rebuildable (line attached): exact size, welded in 2020.1+' do |c, model|
      base = tests.slot(29)
      top = tests.pt(base.x, base.y, 20.mm)
      tests.add_cylinder(model.entities, base, Z_AXIS, 10.mm, 20.mm, 24)
      tests.explode_circles(model.entities, [base, top])
      wall = tests.walls_at(model.entities, base, 10.mm)
      corner = wall.flat_map(&:vertices).find { |vx| (vx.position.z.to_f - top.z.to_f).abs < 1e-6 }
      out = base.vector_to(tests.pt(corner.position.x, corner.position.y, 0))
      model.entities.add_line(corner.position, corner.position.offset(out, 5.mm))
      cylinders, _rejected = CircleMaster::Detector.from_faces(wall)
      next c.check(false, 'cylinder detected') if cylinders.empty?
      change = CircleMaster::VcbParser.parse('22')
      _count, native, welded = CircleMaster::Resizer.resize(cylinders, change)
      wall = tests.walls_at(model.entities, base, 11.mm)
      c.check(native.zero?, 'not rebuilt (line attached to an end circle)')
      c.check(tests.radius_range(wall, base) == [11.0, 11.0], 'every vertex at radius 11 mm',
              tests.radius_range(wall, base).inspect)
      if Sketchup::Entities.method_defined?(:weld)
        c.check(welded == 2, 'both circles welded into one curve', welded.to_s)
      else
        c.check(welded.zero?, 'no weld before SketchUp 2020.1: circles left as edges', welded.to_s)
      end
    end

    test 'R7 Cylinder in an open component: the definition is resized' do |c, model|
      next c.skip('opening a component needs SketchUp 2020.1+ (Model#active_path=)') unless tests.open_path?(model)
      base = tests.slot(30)
      defn = model.definitions.add('CM Test Pin')
      tests.add_cylinder(defn.entities, ORIGIN, Z_AXIS, 10.mm, 20.mm, 24)
      first = model.entities.add_instance(defn, Geom::Transformation.translation(base - ORIGIN))
      second = model.entities.add_instance(defn, Geom::Transformation.translation(base.offset(X_AXIS, 200.mm) - ORIGIN))
      model.active_path = [first]
      # An open instance may report its entities in model coordinates
      # (SketchUp 2020+, see Circle Advanced FSD 2.4): look for the wall at
      # both places.
      wall = tests.walls_at(defn.entities, ORIGIN, 10.mm)
      if wall.empty?
        wall = tests.walls_at(defn.entities, base, 10.mm)
        c.note('open component: entities reported in model coordinates')
      end
      c.check(wall.length == 24, 'wall of the open component found', wall.length.to_s)
      tests.select(model, wall)
      tool = tests.resize_tool(model)
      tests.status.clear
      tool.onUserText('24', tests.view)
      tests.note_feedback(c)
      model.select_tool(nil)
      tests.close_all(model)
      got = tests.circles_at(defn.entities, ORIGIN, tests.pt(0, 0, 20.mm))
      c.check(got == [[[12.0, 24]], [[12.0, 24]]], 'definition: radius 12 mm, native', got.inspect)
      c.check(second.definition == defn && first.definition == defn, 'both instances share the resized definition')
    end

    # --- Segment count in the cylinder commands (EF-12) -----------------------

    test 'R8 Segments in Cylinder Resize Tool: Measurements box, 15;36s, +0,2;48s, several, cone' do |c, model|
      a = tests.slot(35)
      b = a.offset(X_AXIS, 200.mm)
      [a, b].each { |p| tests.add_cylinder(model.entities, p, Z_AXIS, 25.mm, 20.mm, 24) }
      top_a = tests.pt(a.x, a.y, 20.mm)
      top_b = tests.pt(b.x, b.y, 20.mm)
      tests.select(model, tests.walls_at(model.entities, a, 25.mm))
      tool = tests.resize_tool(model)
      v = tests.view
      shown = "#{Sketchup.format_length(50.mm)}; 24s"
      c.check(tests.vcb[:label] == 'Diameter; Segments' && tests.vcb[:value] == shown,
              "Measurements box: Diameter; Segments = #{shown}", tests.vcb.inspect)
      [[shown, 25.0, 24, 'the value shown, typed again: unchanged'], ['15;36s', 7.5, 36, '15;36s'],
       ['+0,2;48s', 7.6, 48, '+0,2;48s']].each do |text, r, n, label|
        tool.onUserText(text, v)
        got = tests.circles_at(model.entities, a, top_a)
        c.check(got == [[[r, n]], [[r, n]]], "#{label}: radius #{r} mm, #{n} segments", got.inspect)
      end
      model.select_tool(nil)
      tests.select(model, tests.walls_at(model.entities, a, 7.6.mm) + tests.walls_at(model.entities, b, 25.mm))
      tool = tests.resize_tool(model)
      tool.onUserText('30s', v)
      got = tests.circles_at(model.entities, a, top_a, b, top_b)
      c.check(got == [[[7.6, 30]], [[7.6, 30]], [[25.0, 30]], [[25.0, 30]]], 'two cylinders, 30s: both 30 segments',
              got.inspect)
      model.select_tool(nil)
      cone = a.offset(X_AXIS, 400.mm)
      cone_top = tests.pt(cone.x, cone.y, 30.mm)
      tests.add_cone(model.entities, cone, 15.mm, 7.mm, 30.mm)
      tests.select(model, tests.walls_at(model.entities, cone, 15.mm))
      tool = tests.resize_tool(model)
      questions = tests.messages.length
      tool.onUserText('48s', v)
      got = tests.circles_at(model.entities, cone, cone_top)
      c.check(got == [[[15.0, 48]], [[7.0, 48]]], 'cone, 48s: stays a cone, 48 segments', got.inspect)
      c.check(tests.messages.length == questions, 'no question asked (segments only)')
    end

    test 'R9 Segments refused when a cylinder cannot be rebuilt: nothing changed; size alone works' do |c, model|
      base = tests.slot(36)
      other = base.offset(X_AXIS, 200.mm)
      [base, other].each { |p| tests.add_cylinder(model.entities, p, Z_AXIS, 10.mm, 20.mm, 24) }
      top = tests.pt(base.x, base.y, 20.mm)
      top_other = tests.pt(other.x, other.y, 20.mm)
      wall = tests.walls_at(model.entities, base, 10.mm)
      corner = wall.flat_map(&:vertices).find { |vx| (vx.position.z.to_f - top.z.to_f).abs < 1e-6 }
      out = base.vector_to(tests.pt(corner.position.x, corner.position.y, 0))
      model.entities.add_line(corner.position, corner.position.offset(out, 5.mm))
      tests.select(model, wall + tests.walls_at(model.entities, other, 10.mm))
      tool = tests.resize_tool(model)
      tests.status.clear
      tool.onUserText('36s', tests.view)
      c.check(tests.status.any? { |s| s.include?('The segment count cannot be changed') },
              'message with the reason', tests.status.last.inspect)
      got = tests.circles_at(model.entities, base, top, other, top_other)
      c.check(got == [[[10.0, 24]]] * 4, 'nothing changed (neither cylinder)', got.inspect)
      tool.onUserText('22', tests.view)
      got = tests.circles_at(model.entities, base, top, other, top_other)
      c.check(got == [[[11.0, 24]]] * 4, 'size alone (22): both resized', got.inspect)
    end

    test 'R10 Resize Cylinders dialog: 36s, then 12;36s; one undo step' do |c, model|
      base = tests.slot(37)
      top = tests.pt(base.x, base.y, 20.mm)
      tests.add_cylinder(model.entities, base, Z_AXIS, 25.mm, 20.mm, 24)
      tests.select(model, tests.walls_at(model.entities, base, 25.mm))
      tests.inputs << %w[Diameter 36s]
      CircleMaster.resize_selection
      got = tests.circles_at(model.entities, base, top)
      c.check(got == [[[25.0, 36]], [[25.0, 36]]], '36s: 36 segments', got.inspect)
      tests.select(model, tests.walls_at(model.entities, base, 25.mm))
      tests.inputs << %w[Diameter 12;36s]
      CircleMaster.resize_selection
      got = tests.circles_at(model.entities, base, top)
      c.check(got == [[[6.0, 36]], [[6.0, 36]]], '12;36s: diameter 12, 36 segments', got.inspect)
      c.later do
        Sketchup.undo
        got = tests.circles_at(model.entities, base, top)
        c.check(got == [[[25.0, 36]], [[25.0, 36]]], 'one undo step: back to diameter 50, 36 segments', got.inspect)
      end
    end

    # --- Robustness -------------------------------------------------------------

    [['X1', 0.5.mm, '1 mm'], ['X2', 0.25.mm, '0,5 mm']].each_with_index do |(id, r, label), i|
      test "#{id} Very small hole, diameter #{label}: 48 segments, then broken and resized" do |c, model|
        o = tests.slot(31 + i)
        tests.add_block(model.entities, o, 10.mm, 10.mm, 2.mm)
        hole = tests.pt(o.x + 5.mm, o.y + 5.mm, 2.mm)
        bottom = tests.pt(hole.x, hole.y, 0)
        tests.push_circle(model.entities, hole, r, -2.mm)
        rm = tests.mm_of(r)
        got = tests.circles_at(model.entities, hole, bottom)
        next c.check(false, 'hole built', got.inspect) unless got == [[[rm, 24]], [[rm, 24]]]
        tests.select(model, tests.arcs_at(model.entities, hole).first.edges)
        tool, _ip = tests.circle_tool(model)
        tool.onUserText('48s', tests.view)
        model.select_tool(nil)
        got = tests.circles_at(model.entities, hole, bottom)
        c.check(got == [[[rm, 48]], [[rm, 48]]], '48s: both ends native, 48 segments, same radius', got.inspect)
        tests.explode_circles(model.entities, [hole, bottom])
        wall = tests.walls_at(model.entities, bottom, r)
        cylinders, rejected = CircleMaster::Detector.from_faces(wall)
        if cylinders.empty?
          c.note("broken: no cylinder detected (#{rejected.uniq.join(', ')})")
        else
          _body, reason = CircleMaster::Resizer.rebuild_body(cylinders.first)
          c.note("broken: not rebuildable (#{reason})") if reason
        end
        tests.select(model, wall)
        tool = tests.resize_tool(model)
        tests.status.clear
        tests.messages.clear
        tool.onUserText('+0,2', tests.view)
        model.select_tool(nil)
        want = (rm + 0.1).round(4)
        got = tests.circles_at(model.entities, hole, bottom)
        ok = c.check(got == [[[want, 48]], [[want, 48]]], "broken, +0,2: rebuilt native, radius #{want} mm", got.inspect)
        unless ok
          tests.note_feedback(c)
          c.note("radius of the vertices: #{tests.radius_range(tests.walls_at(model.entities, bottom, r + 0.2.mm), bottom).inspect} mm")
        end
      end
    end

    test 'X3 No definition created by the commands' do |c, model|
      before = model.definitions.to_a
      base = tests.slot(33)
      tool, ip = tests.circle_tool(model)
      tests.click_circle(tool, ip, base, 20.mm)
      model.select_tool(nil)
      cyl = base.offset(X_AXIS, 200.mm)
      tests.add_cylinder(model.entities, cyl, Z_AXIS, 20.mm, 20.mm, 24)
      tests.select(model, tests.arcs_at(model.entities, cyl).first.edges)
      tool, _ip = tests.circle_tool(model)
      tool.onUserText('36s', tests.view)
      model.select_tool(nil)
      tests.explode_circles(model.entities, [cyl, tests.pt(cyl.x, cyl.y, 20.mm)])
      tests.select(model, tests.walls_at(model.entities, cyl, 20.mm))
      tool = tests.resize_tool(model)
      tool.onUserText('+2', tests.view)
      model.select_tool(nil)
      added = model.definitions.to_a - before
      c.check(added.empty?, 'no new definition (circle, segments, rebuilt cylinder)', added.map(&:name).join(', '))
    end

    # --- Dialogs and interface ----------------------------------------------------

    test 'D1 Settings window: shows the settings, OK saves them, Cancel does not' do |c, _model|
      dialogs = CircleMaster::SettingsDialog
      dialogs.show
      dlg = dialogs.instance_variable_get(:@dialog)
      shown = []
      dlg.add_action_callback('cm_tests_values') { |_ctx, *values| shown.replace(values.map(&:to_s)) }
      read = 'sketchup.cm_tests_values(document.getElementById("segments").value, selectedMode(), selectedCoord())'
      c.later { nil } # page loading
      c.later { nil }
      c.later { dlg.execute_script(read) }
      c.later do
        c.check(shown == %w[48 diameter auto], 'shows 48 segments, diameter, auto', shown.inspect)
        dlg.execute_script('document.getElementById("segments").value = "36"; ' \
                           'document.getElementsByName("mode")[1].checked = true; ' \
                           'document.getElementById("ok").click();')
      end
      c.later do
        s = CircleMaster::Settings
        c.check(s.segments == 36 && s.input_mode == 'radius', 'OK: 36 segments, radius', "#{s.segments}, #{s.input_mode}")
        c.check(!dlg.visible?, 'OK: window closed')
        c.check(tests.writes.include?('CircleMaster/segments') && tests.writes.include?('CircleMaster/input_mode'),
                'saved in CircleMaster (intercepted)')
        dialogs.show
      end
      c.later { nil }
      c.later { nil }
      c.later do
        dialogs.instance_variable_get(:@dialog).execute_script(
          'document.getElementById("segments").value = "12"; document.getElementById("cancel").click();'
        )
      end
      c.later do
        again = dialogs.instance_variable_get(:@dialog)
        c.check(CircleMaster::Settings.segments == 36, 'Cancel: nothing changed', CircleMaster::Settings.segments.to_s)
        c.check(!again.visible?, 'Cancel: window closed')
        again.close if again.visible?
      end
    end

    test 'D2 Extension, toolbar and version' do |c, _model|
      ext = Sketchup.extensions['Circle Master']
      c.check(ext && ext.loaded?, 'extension Circle Master registered and loaded')
      c.check(ext && ext.version == CircleMaster::VERSION, "version #{CircleMaster::VERSION}")
      toolbar = UI.toolbar('Circle Master')
      items = toolbar.respond_to?(:count) ? toolbar.count : nil
      c.check(items.nil? || items >= 4, 'toolbar Circle Master with its buttons', items.inspect)
    end
  end
end
