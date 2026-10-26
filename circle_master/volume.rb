# encoding: UTF-8
# Segment count change of a straight cylinder or truncated cone, from one of
# its end circles. Ported from Circle Re-Segment v0.1.0 (detector.rb,
# resegmenter.rb: Push/Pull method only, validated there with segment
# count changes):
#
# Detection: the wall is a surface of faces joined by soft edges (reached
# from a face touching the circle out of its plane), bounded by exactly two
# coaxial circular loops; no other line attached to the circles; faces
# touching a circle outside the wall lie in its plane; a face at one end at
# least.
#
# Rebuild:
#   1. Snapshot the faces touching each circle (disc or host face with a
#      hole: normal, materials, tag) and their other inner loops (holes);
#      the wall properties.
#   2. Erase the wall and the circles (host faces close themselves).
#   3. Draw the new circle (add_arc, N segments, same phase) on the end that
#      carries a face (host face preferred), find_faces -> disc.
#   4. disc.pushpull up to the plane of the other end (through holes are
#      drilled by SketchUp as with the Push/Pull tool).
#   5. Truncated cone: scale the far circle about its center.
#   6. Restore wall and caps properties; erase new faces that did not exist
#      (disc over a through hole) or that fill a former hole.
#   7. Check: each end is one native ArcCurve of N edges.
# Pointed cones, oblique cylinders and open tubes are refused: Circle
# Re-Segment rebuilds them as welded curves, not native circles.
#
# All positions are in the coordinates the API reports for the active
# context.

module CircleMaster
  module Volume
    MIN_SEGMENTS = 3
    BASE_TOL     = 0.001 # inches, SketchUp internal tolerance
    REL_TOL      = 0.005 # relative to the radius

    # One end circle. vertices: ordered, unique; arc: ArcCurve or nil.
    Loop = Struct.new(:edges, :vertices, :center, :normal, :radius, :arc)

    Body = Struct.new(:faces, :loops) do
      def segments
        loops.map { |l| l.edges.length }
      end
    end

    def self.tolerance(radius)
      [BASE_TOL, radius * REL_TOL].max
    end

    # --- Detection -----------------------------------------------------------

    # Cylinder or truncated cone whose end circle is +curve+ (an ArcCurve
    # touching a face out of its plane). Raises ArgumentError with the reason
    # when it is not supported.
    def self.from_curve(curve)
      normal = curve.normal
      wall = curve.edges.flat_map(&:faces).uniq.find { |f| !f.normal.parallel?(normal) }
      raise ArgumentError, 'Circle on a non planar surface' unless wall
      body, reason = build(surface_of(wall))
      unless body
        raise ArgumentError, "Cylinder not supported (#{reason}): use Circle Re-Segment"
      end
      anchor = curve.first_edge
      unless body.loops.any? { |l| l.edges.include?(anchor) }
        raise ArgumentError, 'Circle shared with another surface: use Circle Re-Segment'
      end
      body
    end

    # Faces reachable from +face+ through soft edges.
    def self.surface_of(face)
      result = [face]
      seen = { face => true }
      queue = [face]
      until queue.empty?
        f = queue.shift
        f.edges.each do |e|
          next unless e.soft?
          e.faces.each do |other|
            next if seen[other]
            seen[other] = true
            result << other
            queue << other
          end
        end
      end
      result
    end

    # Returns [body, nil] or [nil, reason].
    def self.build(faces)
      return [nil, 'not a curved surface'] if faces.length < MIN_SEGMENTS
      face_set = {}
      faces.each { |f| face_set[f] = true }
      boundary = faces.flat_map(&:edges).uniq.select do |e|
        !e.soft? && e.faces.count { |f| face_set[f] } == 1
      end
      loops = build_loops(boundary)
      return [nil, 'open or branching boundary'] unless loops
      return [nil, 'pointed cone or not a cylinder'] unless loops.length == 2
      circles = loops.map { |edges, vertices| fit_circle(edges, vertices) }
      return [nil, 'end is not a circle'] if circles.include?(nil)
      return [nil, 'oblique cylinder or cone'] unless coaxial?(*circles)

      allowed = {}
      circles.each { |c| c.vertices.each { |v| allowed[v] = true } }
      unless faces.all? { |f| f.vertices.all? { |v| allowed[v] } }
        return [nil, 'wall is not a cylinder or cone']
      end

      wall_edge = lambda do |e|
        !e.faces.empty? && e.faces.all? { |f| face_set[f] }
      end
      circles.each do |c|
        loop_set = {}
        c.edges.each { |e| loop_set[e] = true }
        c.vertices.each do |v|
          next if v.edges.all? { |e| loop_set[e] || wall_edge.call(e) }
          return [nil, 'circle is cut or has a line attached']
        end
        tol = tolerance(c.radius)
        c.edges.flat_map(&:faces).uniq.each do |f|
          next if face_set[f]
          on_plane = f.normal.parallel?(c.normal) &&
                     c.center.vector_to(f.vertices.first.position).dot(c.normal).abs < tol
          return [nil, 'circle is shared with another surface'] unless on_plane
        end
      end
      body = Body.new(faces, circles)
      return [nil, 'no face at either end'] unless start_loop(snapshot_caps(body))
      [body, nil]
    end

    # Chains edges into closed loops. Returns [[edges, ordered_vertices], ...]
    # or nil if a vertex does not have exactly two boundary edges.
    def self.build_loops(edges)
      return nil if edges.empty?
      adjacency = Hash.new { |h, k| h[k] = [] }
      edges.each { |e| e.vertices.each { |v| adjacency[v] << e } }
      return nil unless adjacency.values.all? { |list| list.length == 2 }
      loops = []
      used = {}
      edges.each do |start|
        next if used[start]
        loop_edges = []
        vertices = []
        edge = start
        vertex = start.start
        until used[edge]
          used[edge] = true
          loop_edges << edge
          vertices << vertex
          vertex = edge.other_vertex(vertex)
          edge = (adjacency[vertex] - [edge]).first
        end
        loops << [loop_edges, vertices]
      end
      loops
    end

    def self.fit_circle(edges, vertices)
      return nil if vertices.length < MIN_SEGMENTS
      curve = edges.first.curve
      if curve.is_a?(Sketchup::ArcCurve) && curve.count_edges == edges.length &&
         edges.all? { |e| e.curve == curve }
        center = curve.center
        return Loop.new(edges, vertices, center, curve.normal.normalize,
                        center.distance(vertices.first.position).to_f, curve)
      end
      pts = vertices.map(&:position)
      n = pts.length.to_f
      cx = pts.inject(0.0) { |s, p| s + p.x.to_f } / n
      cy = pts.inject(0.0) { |s, p| s + p.y.to_f } / n
      cz = pts.inject(0.0) { |s, p| s + p.z.to_f } / n
      center = Geom::Point3d.new(cx, cy, cz)
      dists = pts.map { |p| p.distance(center).to_f }
      radius = dists.inject(0.0, :+) / n
      return nil if radius <= 0
      tol = tolerance(radius)
      return nil if dists.any? { |d| (d - radius).abs > tol }
      normal = Geom::Vector3d.new(0, 0, 0)
      pts.each_with_index do |p, i|
        q = pts[(i + 1) % pts.length]
        normal += center.vector_to(p).cross(center.vector_to(q))
      end
      return nil if normal.length.to_f < 1e-9
      normal.normalize!
      return nil if pts.any? { |p| center.vector_to(p).dot(normal).abs > tol }
      Loop.new(edges, vertices, center, normal, radius, nil)
    end

    def self.coaxial?(a, b)
      tol = tolerance([a.radius, b.radius].max)
      return false unless a.normal.parallel?(b.normal)
      axis = a.center.vector_to(b.center)
      axis.length.to_f > tol && axis.parallel?(a.normal)
    end

    # --- Rebuild -------------------------------------------------------------

    # Rebuilds +body+ with +n+ segments at both ends.
    def self.rebuild(entities, body, n)
      snap = snapshot(entities, body)
      s = start_loop(snap[:caps])
      raise 'no face at either end of the cylinder' unless s
      pushpull_rebuild(entities, n, body, snap, s)
      check(entities, snap[:frames], n)
    end

    def self.snapshot(entities, body)
      line = axis_line(body)
      wall = body.faces.first
      # Same phase for both circles: x axis through the first vertex of loop 0.
      na = body.loops[0].normal
      xa = body.loops[0].center.vector_to(body.loops[0].vertices.first.position)
      frames = body.loops.map do |c|
        nk = c.normal.dot(na) < 0 ? c.normal.reverse : c.normal.clone
        xk = Geom::Vector3d.linear_combination(1.0, xa, -xa.dot(nk), nk)
        xk.normalize!
        [c.center.clone, xk, nk, c.radius]
      end
      existing = {}
      entities.grep(Sketchup::Face).each { |f| existing[f.entityID] = true }
      {
        line: line,
        wall: {
          material: wall.material, back_material: wall.back_material,
          layer: wall.layer, outward: outward?(wall, line)
        },
        caps: snapshot_caps(body),
        holes: snapshot_holes(body),
        edge_layers: body.loops.map { |c| c.edges.first.layer },
        frames: frames,
        existing: existing
      }
    end

    def self.snapshot_caps(body)
      face_set = {}
      body.faces.each { |f| face_set[f] = true }
      body.loops.map do |c|
        loop_set = {}
        c.edges.each { |e| loop_set[e] = true }
        c.edges.flat_map(&:faces).uniq.reject { |f| face_set[f] }.map do |f|
          {
            disc: f.outer_loop.edges.all? { |e| loop_set[e] },
            normal: f.normal,
            material: f.material,
            back_material: f.back_material,
            layer: f.layer
          }
        end
      end
    end

    # Inner loops (holes) of the faces touching the circles, except the
    # circles themselves: vertex positions of each hole.
    def self.snapshot_holes(body)
      face_set = {}
      body.faces.each { |f| face_set[f] = true }
      holes = []
      body.loops.each do |c|
        loop_set = {}
        c.edges.each { |e| loop_set[e] = true }
        c.edges.flat_map(&:faces).uniq.reject { |f| face_set[f] }.each do |f|
          f.loops.each do |lp|
            next if lp.outer?
            next if lp.edges.any? { |e| loop_set[e] }
            holes << lp.vertices.map { |v| v.position.clone }
          end
        end
      end
      holes
    end

    # Index of the circle to start the Push/Pull from (host face preferred),
    # or nil when no end carries a face.
    def self.start_loop(caps)
      [0, 1].find { |k| caps[k].any? { |c| !c[:disc] } } ||
        [0, 1].find { |k| !caps[k].empty? }
    end

    def self.pushpull_rebuild(entities, n, body, snap, s)
      e = 1 - s
      fs = snap[:frames][s]
      fe = snap[:frames][e]

      entities.erase_entities(body.faces + body.faces.flat_map(&:edges).uniq)

      arc = entities.add_arc(fs[0], fs[1], fs[2], fs[3], 0, 2 * Math::PI, n)
      arc.each { |ed| ed.layer = snap[:edge_layers][s] }
      arc.first.find_faces
      disc = arc.first.faces.find do |f|
        f.outer_loop.edges.all? { |ed| ring_edge?(ed, fs) }
      end
      raise 'no face could be created on the new circle' unless disc
      disc.pushpull(fs[0].vector_to(fe[0]).dot(disc.normal))

      # Truncated cone: the far circle has the start radius until scaled.
      tol = tolerance([fs[3], fe[3]].max)
      if (fe[3] - fs[3]).abs > tol
        far = ring_edges(entities, [fe[0], fe[1], fe[2], fs[3]])
        unless far.empty?
          entities.transform_entities(
            Geom::Transformation.scaling(fe[0], fe[3] / fs[3]), far
          )
        end
      end
      ring_edges(entities, fe).each { |ed| ed.layer = snap[:edge_layers][e] }

      wall_set = {}
      ring_edges(entities, fs).flat_map(&:faces).uniq.each do |f|
        next if f.normal.parallel?(fs[2])
        wall_set[f] = true
        apply_wall(f, snap, fs, fe)
      end
      repair_caps(entities, snap[:frames], snap[:caps], snap[:existing], wall_set)
      repair_holes(entities, snap[:holes], snap[:existing])
    end

    # Raises (the whole operation is then aborted) unless each end is one
    # native ArcCurve of +n+ edges.
    def self.check(entities, frames, n)
      frames.each do |frame|
        edges = ring_edges(entities, frame)
        curve = edges.empty? ? nil : edges.first.curve
        ok = curve.is_a?(Sketchup::ArcCurve) && edges.length == n &&
             curve.count_edges == n &&
             edges.all? { |ed| ed.curve && ed.curve.entityID == curve.entityID }
        raise 'The cylinder could not be rebuilt, nothing was changed' unless ok
      end
    end

    def self.axis_line(body)
      a = body.loops[0]
      [a.center, a.center.vector_to(body.loops[1].center)]
    end

    # True when the face normal points away from the axis.
    def self.outward?(face, line)
      c = face.bounds.center
      radial = c.project_to_line(line).vector_to(c)
      face.normal.dot(radial) > 0
    end

    # Wall face: orientation, materials, tag of the former wall; lateral
    # edges (not on a circle) softened.
    def self.apply_wall(face, snap, *frames)
      props = snap[:wall]
      face.reverse! if outward?(face, snap[:line]) != props[:outward]
      face.material = props[:material]
      face.back_material = props[:back_material]
      face.layer = props[:layer]
      face.edges.each do |ed|
        next if frames.any? { |fr| ring_edge?(ed, fr) }
        ed.soft = true
        ed.smooth = true
      end
    end

    def self.on_circle?(pt, frame)
      center, _xaxis, normal, radius = frame
      tol = tolerance(radius)
      v = center.vector_to(pt)
      v.dot(normal).abs < tol && (v.length.to_f - radius).abs < tol
    end

    def self.ring_edge?(edge, frame)
      on_circle?(edge.start.position, frame) && on_circle?(edge.end.position, frame)
    end

    def self.ring_edges(entities, frame)
      entities.grep(Sketchup::Edge).select { |ed| ring_edge?(ed, frame) }
    end

    # New faces touching a circle: keep those that existed before (disc or
    # host face) with their properties, erase the others. Faces are matched
    # geometrically, not by edge identity.
    def self.repair_caps(entities, frames, caps, existing, wall_set)
      new_faces = entities.grep(Sketchup::Face).reject do |f|
        existing[f.entityID] || wall_set[f]
      end
      handled = {}
      frames.each_with_index do |frame, k|
        new_faces.each do |f|
          next if handled[f] || !f.valid?
          next unless f.edges.any? { |ed| ring_edge?(ed, frame) }
          handled[f] = true
          disc = f.outer_loop.edges.all? { |ed| ring_edge?(ed, frame) }
          rec = caps[k].find { |c| c[:disc] == disc }
          if rec
            f.reverse! if f.normal.dot(rec[:normal]) < 0
            f.material = rec[:material]
            f.back_material = rec[:back_material]
            f.layer = rec[:layer]
          else
            f.erase!
          end
        end
      end
    end

    # A face rebuilt on the plane of a former hole may lie over its edges
    # without being split: find_faces on one hole edge splits it (no edge is
    # erased, so the hole circle stays native), then new faces filling a
    # former hole are erased. +holes+: vertex positions of each hole.
    def self.repair_holes(entities, holes, existing)
      tol = BASE_TOL * 10
      near = lambda { |p, h| h.any? { |q| p.distance(q) < tol } }
      holes.each do |h|
        edge = entities.grep(Sketchup::Edge).find do |ed|
          near.call(ed.start.position, h) && near.call(ed.end.position, h)
        end
        edge.find_faces if edge
      end
      entities.grep(Sketchup::Face).each do |f|
        next if !f.valid? || existing[f.entityID]
        pts = f.outer_loop.vertices.map(&:position)
        filled = holes.any? do |h|
          h.length == pts.length && pts.all? { |p| near.call(p, h) }
        end
        f.erase! if filled
      end
    end
  end
end
