# encoding: UTF-8
# Segment count change of existing native circles and arcs. Entity Info
# offers it for planar circles only, not once a circle ends a cylinder.
#
# The API cannot change the segment count of an ArcCurve: the curve is
# erased and drawn again (method of Re-Cercle v2.0.0, rebuilder.rb).
#
# Planar circle or arc (every face touching it lies in its plane):
#   1. Snapshot, for each arc of the circle (a circle split by lines is
#      rebuilt with all its arcs): the face on each side (center side /
#      outer side: normal, materials, tag), the edge properties, the other
#      inner loops (holes) of these faces.
#   2. Erase the arcs (a host face around the circle closes itself), then
#      add_arc for each one: same center, normal, radius, start vertex and
#      sweep; the new segment count for the selected arcs, their own for
#      the others. Only end vertices touch existing edges, so the arcs stay
#      native (Re-Cercle tests).
#   3. find_faces on each new arc; each face touching it gets the properties
#      of the former face on the same side, or is erased when that side was
#      empty (hole, free circle). The side is tested next to each edge, so it
#      does not depend on the segment count (Re-Cercle's probe points sit
#      next to the former chords, which move here).
#   4. Former holes are split again and emptied (Volume.repair_holes).
#   5. Check: one ArcCurve per arc with its segment count, one face per
#      former face side; otherwise the whole operation is aborted.
#
# End circle of a cylinder or truncated cone: the whole volume is rebuilt
# by Push/Pull (Volume), both ends with the new segment count. End arc of
# the rounded corner of a volume: the curved wall is rebuilt by Push/Pull
# of a helper face (Fillet).
#
# All positions are in the coordinates the API reports for the active
# context, as add_arc expects them.

module CircleMaster
  module Resegmenter
    # Raises ArgumentError, before anything is modified, when the segment
    # count of +curves+ cannot be changed. Returns true when at least one of
    # them does not have +n+ segments yet.
    def self.check(curves, n)
      needed = false
      curves.each do |curve|
        if polygon?(curve)
          raise ArgumentError, 'Polygon: change its number of sides in Entity Info'
        end
        if planar?(curve)
          chain_of(curve).each { |c| check_planar(c) }
          needed ||= curve.count_edges != n
        else
          body = volume_of(curve)
          needed ||= body.segments.any? { |s| s != n }
        end
      end
      needed
    end

    # Body rebuilt for a curve touching faces out of its plane: cylinder or
    # truncated cone for a circle, rounded corner for an arc.
    def self.volume_of(curve)
      closed?(curve) ? Volume.from_curve(curve) : Fillet.from_curve(curve)
    end

    # Gives +n+ segments to the curves of the +anchors+ edges (one edge per
    # selected curve). Arcs of one circle, both ends of a cylinder and both
    # arcs of a rounded corner are rebuilt once.
    def self.run(entities, anchors, n)
      anchors.each do |anchor|
        # Erased by a previous rebuild (same circle or same cylinder).
        next unless anchor.valid?
        curve = anchor.curve
        next unless curve.is_a?(Sketchup::ArcCurve)
        if planar?(curve)
          selected = {}
          anchors.each do |a|
            selected[a.curve.entityID] = true if a.valid? && a.curve
          end
          pieces = chain_of(curve).map do |c|
            [c, selected[c.entityID] ? n : c.count_edges]
          end
          next if pieces.all? { |c, count| c.count_edges == count }
          rebuild_planar(entities, pieces)
        else
          body = volume_of(curve)
          next if body.segments.all? { |s| s == n }
          if body.is_a?(Fillet::Body)
            Fillet.rebuild(entities, body, n)
          else
            Volume.rebuild(entities, body, segments: n)
          end
        end
      end
    end

    def self.polygon?(curve)
      curve.respond_to?(:is_polygon?) && curve.is_polygon?
    end

    def self.planar?(curve)
      normal = curve.normal
      curve.edges.all? { |e| e.faces.all? { |f| f.normal.parallel?(normal) } }
    end

    def self.closed?(curve)
      (curve.end_angle - curve.start_angle).abs >= 2 * Math::PI - 1e-6
    end

    # Start vertex position and sweep angle (around the curve normal).
    def self.arc_frame(curve)
      vs = curve.vertices
      return [vs.first.position, 2 * Math::PI] if closed?(curve)
      sweep = curve.end_angle - curve.start_angle
      sweep += 2 * Math::PI if sweep <= 0
      first = vs.first.position
      last = vs.last.position
      turn = Geom::Transformation.rotation(curve.center, curve.normal, sweep)
      tol = Volume.tolerance(curve.center.distance(first).to_f)
      start = first.transform(turn).distance(last).to_f <= tol ? first : last
      [start, sweep]
    end

    def self.end_vertices(curve)
      vs = curve.vertices
      [vs.first, vs.last].uniq
    end

    def self.radius_of(curve)
      curve.center.distance(curve.vertices.first.position).to_f
    end

    def self.same_circle?(a, b)
      ra = radius_of(a)
      tol = Volume.tolerance(ra)
      a.center.distance(b.center).to_f <= tol && (ra - radius_of(b)).abs <= tol &&
        a.normal.parallel?(b.normal)
    end

    # Arcs of the same circle joined end to end (a circle split by lines).
    def self.chain_of(curve)
      chain = [curve]
      ids = { curve.entityID => true }
      queue = [curve]
      until queue.empty?
        c = queue.shift
        end_vertices(c).each do |v|
          v.edges.each do |e|
            other = e.curve
            next unless other.is_a?(Sketchup::ArcCurve) && !ids[other.entityID]
            next unless same_circle?(c, other)
            ids[other.entityID] = true
            chain << other
            queue << other
          end
        end
      end
      chain
    end

    # Raises ArgumentError when +curve+ cannot be rebuilt in its plane.
    def self.check_planar(curve)
      raise ArgumentError, 'Polygon: change its number of sides in Entity Info' if polygon?(curve)
      own = {}
      curve.edges.each { |e| own[e.entityID] = true }
      ends = end_vertices(curve)
      curve.vertices.each do |v|
        next if ends.include?(v)
        next if v.edges.all? { |e| own[e.entityID] }
        raise ArgumentError, 'A line is attached to the circle: its segments cannot be changed'
      end
      snapshot_sides(curve, curve.center)
    end

    # :inner when +face+ lies on the center side of +edge+, :outer on the
    # other side, nil when it cannot be told.
    def self.side_of(face, edge, center)
      p1 = edge.start.position
      p2 = edge.end.position
      mid = Geom.linear_combination(0.5, p1, 0.5, p2)
      inward = mid.vector_to(center)
      return nil if inward.length.to_f < 1e-9
      len = p1.distance(p2).to_f
      [0.05, 0.01, 0.002].each do |k|
        d = [len * k, Chains::BASE_TOL * 2].max
        inside = face.classify_point(mid.offset(inward, d)) == Sketchup::Face::PointInside
        outside = face.classify_point(mid.offset(inward.reverse, d)) == Sketchup::Face::PointInside
        return :inner if inside && !outside
        return :outer if outside && !inside
      end
      nil
    end

    # Properties of the face on each side of +curve+ ({inner: …, outer: …}).
    # Raises ArgumentError when a side cannot be told or holds two faces.
    def self.snapshot_sides(curve, center)
      sides = {}
      curve.edges.each do |edge|
        edge.faces.each do |f|
          side = side_of(f, edge, center)
          raise ArgumentError, 'The faces around the circle could not be analysed' unless side
          rec = sides[side]
          if rec
            next if rec[:id] == f.entityID
            raise ArgumentError, 'Several faces on one side of the circle'
          end
          sides[side] = {
            id: f.entityID, normal: f.normal.clone, material: f.material,
            back_material: f.back_material, layer: f.layer
          }
        end
      end
      sides
    end

    # Rebuilds the arcs of one circle: +pieces+ = [[ArcCurve, segments], ...].
    def self.rebuild_planar(entities, pieces)
      center = pieces.first.first.center.clone
      plans = pieces.map do |curve, n|
        start, sweep = arc_frame(curve)
        ref = curve.first_edge
        {
          normal: curve.normal.normalize, start: start.clone, sweep: sweep, n: n,
          radius: center.distance(start).to_f, edges: curve.edges.to_a,
          sides: snapshot_sides(curve, center),
          props: [ref.layer, ref.soft?, ref.smooth?, ref.hidden?, ref.material]
        }
      end
      erase = plans.flat_map { |p| p[:edges] }
      erase_ids = {}
      erase.each { |e| erase_ids[e.entityID] = true }
      holes = erase.flat_map(&:faces).uniq.flat_map do |f|
        f.loops.reject { |lp| lp.outer? || lp.edges.any? { |e| erase_ids[e.entityID] } }
               .map { |lp| lp.vertices.map { |v| v.position.clone } }
      end
      existing = {}
      entities.grep(Sketchup::Face).each { |f| existing[f.entityID] = true }

      entities.erase_entities(erase)
      arcs = plans.map do |p|
        normal = p[:normal]
        xaxis = center.vector_to(p[:start])
        xaxis = Geom::Vector3d.linear_combination(1.0, xaxis, -xaxis.dot(normal), normal)
        xaxis.normalize!
        edges = entities.add_arc(center, xaxis, normal, p[:radius], 0, p[:sweep], p[:n])
        edges.each do |e|
          e.layer, e.soft, e.smooth, e.hidden, e.material = p[:props]
        end
        edges
      end
      arcs.each do |edges|
        e = edges.find(&:valid?)
        e.find_faces if e
      end
      repair_sides(arcs, plans, center)
      Volume.repair_holes(entities, holes, existing)
      check_planar_result(arcs, plans, center)
    end

    # Each face touching a new arc gets the properties of the former face on
    # the same side, or is erased when that side was empty.
    def self.repair_sides(arcs, plans, center)
      handled = {}
      arcs.each_with_index do |edges, i|
        sides = plans[i][:sides]
        edges.select(&:valid?).each do |edge|
          edge.faces.each do |f|
            next if handled[f.entityID]
            handled[f.entityID] = true
            side = side_of(f, edge, center)
            raise 'A face around the circle could not be restored' unless side
            rec = sides[side]
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
    end

    # Raises (the whole operation is then aborted) unless each new arc is one
    # ArcCurve with its segment count and one face per former face side.
    def self.check_planar_result(arcs, plans, center)
      arcs.each_with_index do |edges, i|
        p = plans[i]
        curve = edges.first && edges.first.valid? ? edges.first.curve : nil
        ok = curve.is_a?(Sketchup::ArcCurve) && curve.count_edges == p[:n] &&
             edges.all? { |e| e.valid? && e.curve && e.curve.entityID == curve.entityID }
        if ok
          found = { inner: {}, outer: {} }
          edges.each do |e|
            e.faces.each do |f|
              side = side_of(f, e, center)
              found[side][f.entityID] = true if side
            end
          end
          ok = [:inner, :outer].all? { |s| found[s].size == (p[:sides][s] ? 1 : 0) }
        end
        raise 'A circle or arc could not be rebuilt, nothing was changed' unless ok
      end
    end
  end
end
