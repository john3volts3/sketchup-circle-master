# encoding: UTF-8
# Segment count change of the rounded corner (fillet) of a volume: an arc at
# each end of a straight curved wall, the wall joining flat faces at its two
# straight end edges. Validated by the console diagnostic
# tools/spike/diag_fillet_segments.rb (SketchUp 2021: outer and inner
# corners, 12 -> 24 and 12 -> 6 segments).
#
# Lateral edges drawn afterwards would split the arcs (Circle Re-Segment
# tests): the wall is rebuilt by Push/Pull, as for cylinders (Volume):
#   1. Snapshot: the face at each end (top/bottom), their other inner loops
#      (holes), the wall properties, the softening of the two end edges.
#   2. Erase the wall, its inner lateral edges and both arcs; the two end
#      edges stay (they bound the flat side faces). The end faces disappear
#      (their outer loop is broken).
#   3. On the end that carries a face: new arc (N segments, same start and
#      sweep) and two helper lines closing a face on the EMPTY side of the
#      arc: lines to the corner point (outer corner) or radii to the center
#      (inner corner). find_faces: helper face + end face.
#   4. Push/Pull of the helper face up to the plane of the other end: curved
#      wall and other arc, both native.
#   5. find_faces on the other arc (its end face), erase the helper edges
#      (their faces go with them), restore the faces, repair former holes.
#   6. Check: two native arcs of N edges, N wall faces, one edge at each
#      tangent point, end faces as before, nothing left on the empty side;
#      otherwise the whole operation is aborted.
#
# All positions are in the coordinates the API reports for the active
# context.

module CircleMaster
  module Fillet
    # One end: the arc, its edges, its face (or nil), its start/end vertices.
    End = Struct.new(:arc, :edges, :cap, :first, :last)

    # ends: [start end (carries a face), other end]; sweep: around the
    # start arc normal; convex: outer corner (material on the center side).
    Body = Struct.new(:ends, :walls, :laterals, :end_edges, :sweep, :convex) do
      def segments
        [ends[0].edges.length]
      end
    end

    FAILED = 'The rounded corner could not be rebuilt, nothing was changed'.freeze

    # --- Detection -----------------------------------------------------------

    # Rounded corner whose end arc is +curve+ (an open ArcCurve touching faces
    # out of its plane). Raises ArgumentError with the reason when it is not
    # supported.
    def self.from_curve(curve)
      nn = curve.normal
      edges = curve.edges.to_a
      walls = edges.map { |e| e.faces.reject { |f| f.normal.parallel?(nn) } }
      refuse('the wall is not one face per segment') unless walls.all? { |fs| fs.size == 1 }
      walls = walls.map(&:first)
      refuse('the wall faces are not rectangles') unless walls.all? { |f| f.edges.size == 4 }

      other_edges = edges.each_with_index.map do |e, i|
        walls[i].edges.find { |x| (x.vertices & e.vertices).empty? }
      end
      others = other_edges.compact.map(&:curve).compact.uniq
      other = others.size == 1 ? others.first : nil
      unless other.is_a?(Sketchup::ArcCurve) && other_edges.all? &&
             other.count_edges == edges.size && !Resegmenter.closed?(other)
        refuse('the other end is not one native arc with the same segment count')
      end

      first, last, = frame(curve)
      wall_ids = {}
      walls.each { |f| wall_ids[f.entityID] = true }
      own = {}
      (edges + other.edges.to_a).each { |e| own[e.entityID] = true }
      end_edge = lambda do |v|
        v.edges.find { |x| !own[x.entityID] && x.faces.any? { |f| wall_ids[f.entityID] } }
      end
      v1 = end_edge.call(first)
      v2 = end_edge.call(last)
      refuse('missing straight edge at a tangent point') unless v1 && v2
      h = first.position.vector_to(v1.other_vertex(first).position)
      refuse('oblique wall') unless h.parallel?(nn)

      radius = curve.center.distance(first.position).to_f
      tol = Volume.tolerance(radius)
      far_center = curve.center.offset(h)
      far_radius = other.center.distance(other.vertices.first.position).to_f
      unless other.center.distance(far_center).to_f <= tol && (far_radius - radius).abs <= tol
        refuse('its two arcs have different radii (resize both arcs together)')
      end

      laterals = walls.flat_map(&:edges).uniq.reject do |x|
        own[x.entityID] || x == v1 || x == v2
      end
      lateral_ids = {}
      laterals.each { |x| lateral_ids[x.entityID] = true }
      [curve, other].each do |arc|
        ends = [arc.vertices.first, arc.vertices.last]
        arc.vertices.each do |v|
          next if ends.include?(v)
          next if v.edges.all? { |x| own[x.entityID] || lateral_ids[x.entityID] }
          refuse('a line is attached to an arc')
        end
      end

      ends = [curve, other].map do |arc|
        caps = arc.edges.flat_map(&:faces).uniq.select { |f| f.normal.parallel?(nn) }
        refuse('several faces at one end') if caps.size > 1
        End.new(arc, arc.edges.to_a, caps.first)
      end
      ends.reverse! if ends[0].cap.nil?
      refuse('no face at either end') unless ends[0].cap

      start = ends[0]
      start.first, start.last, sweep = frame(start.arc)
      # End edges in the order of the start arc (it may be the other arc).
      v1 = end_edge.call(start.first)
      v2 = end_edge.call(start.last)
      refuse('missing straight edge at a tangent point') unless v1 && v2
      center = start.arc.center
      side = Resegmenter.side_of(start.cap, start.edges.find { |e| e.faces.include?(start.cap) }, center)
      refuse('the end face could not be analysed') unless side
      convex = side == :inner
      if convex && sweep >= Math::PI - 1e-6
        refuse('outer corner of 180 degrees or more')
      end
      if ends[1].cap
        far_side = Resegmenter.side_of(ends[1].cap,
                                       ends[1].edges.find { |e| e.faces.include?(ends[1].cap) },
                                       ends[1].arc.center)
        refuse('the end faces are on different sides') unless far_side == side
      end
      Body.new(ends, walls, laterals, [v1, v2], sweep, convex)
    end

    def self.refuse(reason)
      raise ArgumentError, "Rounded corner not supported (#{reason})"
    end

    # [start vertex, end vertex, sweep] around the arc normal.
    def self.frame(arc)
      vs = arc.vertices
      sweep = arc.end_angle - arc.start_angle
      sweep += 2 * Math::PI if sweep <= 0
      turn = Geom::Transformation.rotation(arc.center, arc.normal, sweep)
      tol = Volume.tolerance(arc.center.distance(vs.first.position).to_f)
      if vs.first.position.transform(turn).distance(vs.last.position).to_f <= tol
        [vs.first, vs.last, sweep]
      else
        [vs.last, vs.first, sweep]
      end
    end

    # --- Rebuild -------------------------------------------------------------

    # Rebuilds +body+ with +n+ segments in both arcs.
    def self.rebuild(entities, body, n)
      start, far = body.ends
      c = start.arc.center.clone
      nn = start.arc.normal.normalize
      t1 = start.first.position.clone
      t2 = start.last.position.clone
      r = c.distance(t1).to_f
      tol = Volume.tolerance(r)
      v1 = body.end_edges.first
      h = t1.vector_to(v1.other_vertex(start.first).position)
      cb = c.offset(h)
      t1b = t1.offset(h)
      t2b = t2.offset(h)
      if body.convex
        d1 = nn.cross(c.vector_to(t1))
        d2 = nn.cross(c.vector_to(t2))
        q = Geom.intersect_line_line([t1, d1], [t2, d2])
        raise FAILED unless q
      else
        q = c
      end
      qb = q.offset(h)
      empty_side = body.convex ? :outer : :inner
      axis = [c, nn]

      # 1. Snapshot.
      caps = [start.cap, far.cap]
      cap_props = caps.map { |f| f ? face_props(f) : nil }
      arc_ids = {}
      (start.edges + far.edges).each { |e| arc_ids[e.entityID] = true }
      holes = caps.compact.flat_map do |f|
        f.loops.reject { |lp| lp.outer? || lp.edges.any? { |e| arc_ids[e.entityID] } }
               .map { |lp| lp.vertices.map { |v| v.position.clone } }
      end
      existing = {}
      entities.grep(Sketchup::Face).each { |f| existing[f.entityID] = true }
      wall = body.walls.first
      wall_props = {
        material: wall.material, back_material: wall.back_material,
        layer: wall.layer, outward: Volume.outward?(wall, axis)
      }
      ends_soft = body.end_edges.map { |e| [e.soft?, e.smooth?] }
      layers = [start.edges.first.layer, far.edges.first.layer]
      xaxis = c.vector_to(t1)
      xaxis.normalize!

      # 2. Erase the wall and both arcs.
      entities.erase_entities(body.walls + body.laterals + start.edges + far.edges)

      # 3. New arc and helper face on the empty side.
      entities.add_line(t1, q)
      entities.add_line(q, t2)
      arc = entities.add_arc(c, xaxis, nn, r, 0, body.sweep, n)
      arc.each { |e| e.layer = layers[0] }
      arc.first.find_faces
      helper = arc.first.faces.find { |f| Resegmenter.side_of(f, arc.first, c) == empty_side }
      raise FAILED unless helper

      # 4. Push/Pull up to the other end.
      helper.pushpull(c.vector_to(cb).dot(helper.normal))
      far_arc = ring_edges(entities, cb, nn, r, tol)
      far_arc.each { |e| e.layer = layers[1] }
      far_arc.first.find_faces unless far_arc.empty?

      # 5. Clean up and restore.
      near = lambda { |a, b| a.distance(b).to_f <= tol }
      joins = lambda do |e, a, b|
        (near.call(e.start.position, a) && near.call(e.end.position, b)) ||
          (near.call(e.start.position, b) && near.call(e.end.position, a))
      end
      helpers = entities.grep(Sketchup::Edge).select do |e|
        joins.call(e, t1, q) || joins.call(e, q, t2) || joins.call(e, t1b, qb) ||
          joins.call(e, qb, t2b) || joins.call(e, q, qb)
      end
      entities.erase_entities(helpers)

      arcs = [arc.select(&:valid?), far_arc.select(&:valid?)]
      centers = [c, cb]
      on_arc = lambda do |e|
        centers.any? { |ctr| on_circle?(e.start.position, ctr, nn, r, tol) && on_circle?(e.end.position, ctr, nn, r, tol) }
      end
      walls = arcs[0].flat_map(&:faces).uniq.reject { |f| f.normal.parallel?(nn) }
      walls.each do |f|
        f.reverse! if Volume.outward?(f, axis) != wall_props[:outward]
        f.material = wall_props[:material]
        f.back_material = wall_props[:back_material]
        f.layer = wall_props[:layer]
        f.edges.each do |e|
          next if on_arc.call(e) || joins.call(e, t1, t1b) || joins.call(e, t2, t2b)
          e.soft = true
          e.smooth = true
        end
      end
      end_edges = [[t1, t1b], [t2, t2b]].map do |a, b|
        entities.grep(Sketchup::Edge).select { |e| joins.call(e, a, b) }
      end
      end_edges.each_with_index do |list, i|
        list.each { |e| e.soft, e.smooth = ends_soft[i] }
      end
      arcs.each_with_index do |edges, k|
        edges.flat_map(&:faces).uniq.each do |f|
          next unless f.valid? && f.normal.parallel?(nn)
          edge = edges.find { |e| e.faces.include?(f) }
          side = Resegmenter.side_of(f, edge, centers[k])
          next unless side # reported by check
          if side != empty_side && cap_props[k]
            apply_face(f, cap_props[k])
          else
            f.erase!
          end
        end
      end
      Volume.repair_holes(entities, holes, existing)

      # 6. Check.
      check(arcs, centers, nn, n, end_edges, cap_props, empty_side)
    end

    def self.face_props(face)
      {
        normal: face.normal.clone, material: face.material,
        back_material: face.back_material, layer: face.layer
      }
    end

    def self.apply_face(face, props)
      face.reverse! if face.normal.dot(props[:normal]) < 0
      face.material = props[:material]
      face.back_material = props[:back_material]
      face.layer = props[:layer]
    end

    def self.on_circle?(pt, center, normal, radius, tol)
      v = center.vector_to(pt)
      v.dot(normal).abs <= tol && (v.length.to_f - radius).abs <= tol
    end

    def self.ring_edges(entities, center, normal, radius, tol)
      entities.grep(Sketchup::Edge).select do |e|
        on_circle?(e.start.position, center, normal, radius, tol) &&
          on_circle?(e.end.position, center, normal, radius, tol)
      end
    end

    # Raises (the whole operation is then aborted) unless both arcs are one
    # native ArcCurve of +n+ edges with +n+ wall faces between them, one
    # edge at each tangent point, an end face where there was one and no
    # face on the empty side.
    def self.check(arcs, centers, normal, n, end_edges, cap_props, empty_side)
      ok = arcs.all? do |edges|
        curve = edges.empty? ? nil : edges.first.curve
        curve.is_a?(Sketchup::ArcCurve) && edges.size == n && curve.count_edges == n &&
          edges.all? { |e| e.valid? && e.curve && e.curve.entityID == curve.entityID }
      end
      ok &&= end_edges.all? { |list| list.size == 1 }
      ok &&= arcs[0].flat_map(&:faces).uniq.count { |f| !f.normal.parallel?(normal) } == n
      arcs.each_with_index do |edges, k|
        break unless ok
        sides = edges.flat_map do |e|
          e.faces.select { |f| f.normal.parallel?(normal) }
                 .map { |f| Resegmenter.side_of(f, e, centers[k]) }
        end
        ok &&= !sides.include?(empty_side) && !sides.include?(nil)
        ok &&= sides.empty? == cap_props[k].nil?
      end
      raise FAILED unless ok
    end
  end
end
