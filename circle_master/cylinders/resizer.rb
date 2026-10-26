# encoding: UTF-8
# Resizing of detected cylinders: each end circle is resized in turn, like
# editing its radius in Entity Info.
#
# Each vertex is moved radially with Entities#transform_by_vectors, one at a
# time, re-reading positions before each move: moving one vertex of a native
# circle (ArcCurve) makes SketchUp rescale the whole circle, so the remaining
# vertices are then already in place and skipped. Exploded circles need every
# vertex moved. Other non-native circles (welded Curve, arcs split by a solid
# operation) are exploded first: moving a vertex of a plain Curve has no
# effect. Each circle is then checked against its target radius. Nothing is
# erased: host faces (hole in a block) and their materials are kept.
#
# A cylinder with a non-native end circle is rebuilt instead, directly at its
# target size, with two native circles (Rebuilder, method of Re-Cercle: its
# faces are recreated). When that is not possible, it is resized as above and
# its non-native circles are welded into one curve (Entities#weld), without
# erasing any face.
#
# The target radius is computed per circle: an absolute value gives both ends
# the same size (a cone becomes a cylinder), an increment is added to each end
# (a cone stays a cone, with the same angle).

module CircleMaster
  module Resizer
    EPSILON = 1e-6 # inches

    # Resizes +cylinders+ as requested by +change+ (VcbParser::Result: value
    # or increment) in one undoable operation. Nothing is changed if a
    # circle would get a zero or negative radius.
    # Returns [cylinders resized, circles rebuilt as native, circles welded,
    # one vertex per resized cylinder (to find it again afterwards)].
    def self.resize(cylinders, change)
      plan = cylinders.map do |cyl|
        cyl.loops.map { |loop| [loop, VcbParser.target_radius(change, loop.radius)] }
      end
      if plan.flatten(1).any? { |_loop, radius| radius <= EPSILON }
        raise ArgumentError, 'The resulting size would be zero or negative'
      end
      model = Sketchup.active_model
      entities = model.active_entities
      count = 0
      native = 0
      welded = 0
      anchors = []
      model.start_operation("#{PLUGIN_NAME} — Resize Cylinders", true)
      begin
        plan.each_with_index do |loops, i|
          Sketchup.status_text =
            "#{PLUGIN_NAME} — Cylinder #{i + 1}/#{cylinders.length}"
          broken = loops.count { |loop, _radius| loop.arc.nil? }
          reason = broken > 0 ? Rebuilder.unsupported_reason(cylinders[i]) : nil
          if broken > 0 && reason.nil?
            anchors << Rebuilder.rebuild(entities, cylinders[i], loops.map(&:last))
            native += broken
          else
            puts "[#{PLUGIN_NAME}] Not rebuilt as native circles (#{reason}): welded" if reason
            loops.each do |loop, radius|
              explode_loop(loop)
              resize_loop(entities, loop, radius)
              check_loop(loop, radius)
              welded += 1 if repair_loop(entities, loop, radius)
            end
            anchors << loops.first.first.vertices.first
          end
          count += 1
        end
        model.commit_operation
      rescue => e
        model.abort_operation
        raise e
      end
      [count, native, welded, anchors]
    end

    # Status text suffix reporting the repaired circles.
    def self.repair_note(native, welded)
      note = ''
      note += ", #{native} circle(s) rebuilt as native circles" if native > 0
      note += ", #{welded} circle(s) welded (not native, see Ruby Console)" if welded > 0
      note
    end

    # Asks before an absolute value turns cones into cylinders.
    # Returns true to go on.
    def self.confirm_cones(cylinders, change)
      return true if change.delta?
      cones = cylinders.count(&:cone?)
      return true if cones.zero?
      msg = "#{PLUGIN_NAME} — #{cones} cone(s) will become cylinders " \
            "(#{VcbParser.describe(change)} at both ends).\n\n" \
            'Continue? (Type +1 or -0.1 to keep them cones.)'
      UI.messagebox(msg, MB_YESNO) == IDYES
    end

    # Welds the edges of an exploded (already resized) circle into one curve,
    # as Re-Cercle does, so that one click selects the whole circle again.
    # The result is a plain Curve, not an ArcCurve. Requires
    # Entities#weld (SketchUp 2020.1+). Returns true if repaired.
    def self.repair_loop(entities, loop, _radius)
      return false if loop.arc
      return false unless entities.respond_to?(:weld)
      return false unless loop.vertices.all?(&:valid?)
      verts = loop.vertices
      edges = verts.each_with_index.map { |v, i| v.common_edge(verts[(i + 1) % verts.length]) }
      return false if edges.include?(nil)
      curve = edges.first.curve
      return false if curve && edges.all? { |e| e.curve == curve } # already one curve
      entities.weld(edges)
      true
    end

    # Explodes the curves of a non-native circle (welded Curve, or arcs split
    # by a solid operation) before its vertices are moved: moving a vertex of
    # a plain Curve has no effect. The circle is welded again afterwards.
    def self.explode_loop(loop)
      return if loop.arc
      verts = loop.vertices
      verts.each_with_index do |v, i|
        next unless v.valid?
        edge = v.common_edge(verts[(i + 1) % verts.length])
        edge.explode_curve if edge && edge.curve
      end
    end

    # Raises (the whole operation is then aborted) if a circle did not reach
    # its target radius, instead of silently leaving a cone.
    def self.check_loop(loop, radius)
      tol = Detector.tolerance(radius)
      ok = loop.vertices.all? do |v|
        v.valid? && (loop.center.distance(v.position).to_f - radius).abs <= tol
      end
      raise 'An end circle could not be resized, nothing was changed' unless ok
    end

    def self.resize_loop(entities, loop, radius)
      loop.vertices.each do |vertex|
        next unless vertex.valid?
        dir = loop.center.vector_to(vertex.position)
        next if dir.length.to_f < EPSILON
        next if (dir.length.to_f - radius).abs < EPSILON
        dir.length = radius
        target = loop.center.offset(dir)
        entities.transform_by_vectors([vertex], [vertex.position.vector_to(target)])
      end
    end
  end
end
