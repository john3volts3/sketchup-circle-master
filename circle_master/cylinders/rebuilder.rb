# encoding: UTF-8
# Native rebuild of a cylinder or truncated cone whose end circle is not a
# native circle (welded Curve, exploded edges, arcs split by a solid
# operation), directly at its target radii. Ported from Re-Cercle v2.0.0
# (volume.rb, itself adapted from Circle Re-Segment), where it is validated.
#
# SketchUp has no API to turn existing edges into an ArcCurve, and add_arc
# drawn over vertices already connected to a wall is fragmented: the whole
# cylinder is rebuilt.
#   1. Snapshot the faces touching each circle (disc or host face with a
#      hole: normal, materials, tag) and their other inner loops (holes);
#      the wall properties.
#   2. Erase the wall and the circles (host faces close themselves).
#   3. Draw the new circle (add_arc, same phase and segment count, target
#      radius) on the end that carries a face (host face preferred),
#      find_faces -> disc.
#   4. disc.pushpull up to the plane of the other end (through holes are
#      drilled by SketchUp as with the Push/Pull tool).
#   5. Other end with a different target radius: scale its circle about
#      its center.
#   6. Restore wall and caps properties; erase new faces that did not
#      exist (disc over a through hole) or that fill a former hole.
# Both end circles are then native ArcCurves. Recreated faces lose their
# texture position and attributes.

module CircleMaster
  module Rebuilder
    def self.tolerance(radius)
      Detector.tolerance(radius)
    end

    # --- Eligibility -----------------------------------------------------------

    # nil when +cyl+ (Detector::Cylinder) can be rebuilt natively, else the
    # reason (it is then resized and welded instead).
    def self.unsupported_reason(cyl)
      unless cyl.valid? && cyl.loops.all? { |l| l.edges.all?(&:valid?) }
        return 'cylinder changed since its detection'
      end
      a, b = cyl.loops
      return 'end circles with different segment counts' if a.edges.length != b.edges.length
      if a.center.distance(b.center).to_f <= tolerance([a.radius, b.radius].max)
        return 'zero height'
      end

      face_set = {}
      cyl.faces.each { |f| face_set[f] = true }
      allowed = {}
      cyl.loops.each { |c| c.vertices.each { |v| allowed[v] = true } }
      unless cyl.faces.all? { |f| f.vertices.all? { |v| allowed[v] } }
        return 'wall with extra vertices'
      end
      wall_edge = ->(e) { !e.faces.empty? && e.faces.all? { |f| face_set[f] } }
      cyl.loops.each do |c|
        loop_set = {}
        c.edges.each { |e| loop_set[e] = true }
        c.vertices.each do |v|
          next if v.edges.all? { |e| loop_set[e] || wall_edge.call(e) }
          return 'line attached to an end circle'
        end
        tol = tolerance(c.radius)
        c.edges.flat_map(&:faces).uniq.each do |f|
          next if face_set[f]
          on_plane = f.normal.parallel?(c.normal) &&
                     c.center.vector_to(f.vertices.first.position).dot(c.normal).abs < tol
          return 'end circle shared with another surface' unless on_plane
        end
      end
      return 'no face at either end' unless start_loop(snapshot_caps(cyl))
      nil
    end

    # --- Rebuild ---------------------------------------------------------------

    # Rebuilds +cyl+ in +entities+ with native end circles of +radii+ (one
    # per loop). Returns a vertex of the rebuilt cylinder.
    def self.rebuild(entities, cyl, radii)
      snap = snapshot(entities, cyl, radii)
      s = start_loop(snap[:caps])
      raise 'no face at either end of the cylinder' unless s
      pushpull_rebuild(entities, cyl, snap, s)
    end

    def self.snapshot(entities, body, radii)
      line = axis_line(body)
      wall = body.faces.first
      # Same phase for both circles: x axis through the first vertex of
      # loop 0, so that the new vertices come back in the same directions.
      a = body.loops[0]
      xa = a.center.vector_to(a.vertices.first.position)
      frames = body.loops.each_with_index.map do |c, k|
        nk = c.normal.dot(a.normal) < 0 ? c.normal.reverse : c.normal.clone
        xk = Geom::Vector3d.linear_combination(1.0, xa, -xa.dot(nk), nk)
        xk.normalize!
        [c.center.clone, xk, nk, radii[k]]
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
        segments: a.edges.length,
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
          disc = f.outer_loop.edges.all? { |e| loop_set[e] }
          {
            disc: disc,
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

    def self.pushpull_rebuild(entities, body, snap, s)
      e = 1 - s
      fs = snap[:frames][s]
      fe = snap[:frames][e]
      n = snap[:segments]

      entities.erase_entities(body.faces + body.faces.flat_map(&:edges).uniq)

      arc = entities.add_arc(fs[0], fs[1], fs[2], fs[3], 0, 2 * Math::PI, n)
      arc.each { |ed| ed.layer = snap[:edge_layers][s] }
      arc.first.find_faces
      disc = arc.first.faces.find do |f|
        f.outer_loop.edges.all? { |ed| ring_edge?(ed, fs) }
      end
      raise 'no face could be created on the new circle' unless disc
      disc.pushpull(fs[0].vector_to(fe[0]).dot(disc.normal))

      # Different radius at the other end: the far circle has the start
      # radius until scaled.
      tol = tolerance([fs[3], fe[3]].max)
      if (fe[3] - fs[3]).abs > tol
        far = ring_edges(entities, [fe[0], fe[1], fe[2], fs[3]])
        unless far.empty?
          entities.transform_entities(
            Geom::Transformation.scaling(fe[0], fe[3] / fs[3]), far)
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

      # Both ends must now be one native circle of the target size.
      rings = [fs, fe].map { |fr| ring_edges(entities, fr) }
      unless rings.all? { |r| r.length == n && r.all? { |ed| ed.curve.is_a?(Sketchup::ArcCurve) } }
        raise 'The cylinder could not be rebuilt, nothing was changed'
      end
      rings.first.first.start
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
    # former hole are erased.
    def self.repair_holes(entities, holes, existing)
      tol = Detector::BASE_TOL * 10
      near = ->(p, h) { h.any? { |q| p.distance(q) < tol } }
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
