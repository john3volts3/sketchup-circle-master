# encoding: UTF-8
# Ported from Solid Progress 2.0.1 (solid_progress/circle_restore/detector.rb),
# itself ported from Re-Cercle v2.0.0 (re_cercle/detector.rb): chain
# detection only (Run, Chain, chain_from and the geometry it needs),
# unchanged except the namespace (CircleMaster::Chains) and the collinearity
# test of circumcircle, made relative to the size. The search of every
# chain of a solid and their classification (find_chains, analyse) are not
# needed by Circle Master. Circle Master does not depend on either plugin.
#
# A chain is a polygon whose corners lie on one circle and turn by the same
# angle (equal chords): closed = circle (6+ segments), open = arc (3+
# segments). An edge split into collinear pieces counts as one segment
# (run): split points left by a solid operation do not change the circle.
#
# Positions are read in the coordinates of the entities that hold the
# chain.

module CircleMaster
  module Chains
    BASE_TOL   = 0.001 # inches, SketchUp internal tolerance
    REL_TOL    = 0.005 # relative to the radius
    STEP_TOL   = 0.01  # relative difference between segment angles
    MAX_STEP   = Math::PI / 3 * 1.01 # at least 6 segments per turn
    MIN_CIRCLE = 6
    MIN_ARC    = 3
    MAX_RUNS   = 10_000

    # Straight polygon segment: one edge, or collinear edges (split points).
    # vertices: ordered from a to b.
    Run = Struct.new(:edges, :vertices) do
      def a
        vertices.first
      end

      def b
        vertices.last
      end

      def reverse
        Run.new(edges.reverse, vertices.reverse)
      end
    end

    # Runs turn counterclockwise about +normal+ by +step+ (radians).
    Chain = Struct.new(:entities, :runs, :closed, :center, :normal, :radius, :step) do
      def edges
        runs.flat_map(&:edges)
      end

      # Polygon corners (run ends), in order.
      def corners
        list = runs.map(&:a)
        list << runs.last.b unless closed
        list
      end

      # Extra vertices splitting a segment into collinear edges.
      def splits
        runs.flat_map { |r| r.vertices[1..-2] }
      end
    end

    def self.tolerance(radius)
      [BASE_TOL, radius * REL_TOL].max
    end

    # --- Geometry --------------------------------------------------------------

    def self.scale(vector, factor)
      Geom::Vector3d.new(vector.x * factor, vector.y * factor, vector.z * factor)
    end

    # Circle through 3 points: [center, normal, radius], or nil if collinear.
    # p1 -> p2 -> p3 turn counterclockwise about the normal.
    def self.circumcircle(p1, p2, p3)
      a = p3.vector_to(p1)
      b = p3.vector_to(p2)
      axb = a.cross(b)
      d = axb.dot(axb).to_f
      # Collinear when the angle between a and b is null: relative test,
      # whatever the size (the absolute threshold of Re-Cercle, d < 1e-12,
      # took the corners of a 1 mm circle of 48 segments for collinear).
      return nil if d <= 1e-12 * a.dot(a).to_f * b.dot(b).to_f
      num = (scale(b, a.dot(a)) - scale(a, b.dot(b))).cross(axb)
      center = p3 + scale(num, 0.5 / d)
      [center, axb.normalize, center.distance(p1).to_f]
    end

    def self.signed_angle(center, normal, p, q)
      u = center.vector_to(p)
      v = center.vector_to(q)
      return 0.0 if u.length.to_f < 1e-12 || v.length.to_f < 1e-12
      ang = u.angle_between(v)
      u.cross(v).dot(normal) < 0 ? -ang : ang
    end

    def self.on_circle?(pt, center, normal, radius)
      v = center.vector_to(pt)
      t = tolerance(radius)
      (v.length.to_f - radius).abs < t && v.dot(normal).abs < t
    end

    # Signed angle covered by +runs+ of +chain+.
    def self.sweep_of(chain, runs)
      runs.inject(0.0) do |sum, r|
        sum + signed_angle(chain.center, chain.normal, r.a.position, r.b.position)
      end
    end

    # --- Chain detection -------------------------------------------------------

    # Maximal straight run of collinear edges containing +edge+.
    def self.run_of(edge)
      edges = [edge]
      verts = [edge.start, edge.end]
      2.times do
        loop do
          v = verts.last
          dir = verts[-2].position.vector_to(v.position)
          nxt = v.edges.select do |e|
            e != edges.last &&
              v.position.vector_to(e.other_vertex(v).position).samedirection?(dir)
          end
          break unless nxt.length == 1 && !edges.include?(nxt.first)
          edges << nxt.first
          verts << nxt.first.other_vertex(v)
        end
        edges.reverse!
        verts.reverse!
      end
      Run.new(edges, verts)
    end

    # Runs leaving +vertex+ (oriented from it), made of edges not in +used+.
    def self.runs_from(vertex, used)
      runs = vertex.edges.reject { |e| used[e] }.map do |e|
        run = run_of(e)
        next nil if run.edges.any? { |x| used[x] }
        if run.a == vertex
          run
        elsif run.b == vertex
          run.reverse
        end
      end
      runs.compact.uniq { |r| r.edges.first.entityID }
    end

    # Run continuing the polygon from +vertex+ by +step+ (signed), or nil.
    def self.next_run(vertex, used, center, normal, radius, step)
      best = nil
      best_err = nil
      runs_from(vertex, used).each do |run|
        q = run.b.position
        next unless on_circle?(q, center, normal, radius)
        err = (signed_angle(center, normal, vertex.position, q) - step).abs
        next unless err < step.abs * STEP_TOL
        next if best && err >= best_err
        best = run
        best_err = err
      end
      best
    end

    # Longest circle or arc through +edge+, or nil.
    def self.chain_from(edge)
      seed = run_of(edge)
      best = nil
      [seed, seed.reverse].each do |r0|
        used = {}
        r0.edges.each { |e| used[e] = true }
        runs_from(r0.b, used).each do |r1|
          circle = circumcircle(r0.a.position, r0.b.position, r1.b.position)
          next unless circle
          center, normal, radius = circle
          step = signed_angle(center, normal, r0.a.position, r0.b.position)
          step1 = signed_angle(center, normal, r0.b.position, r1.b.position)
          next unless step > 0 && step <= MAX_STEP
          next unless (step1 - step).abs < step * STEP_TOL
          chain = grow(edge.parent.entities, [r0, r1], center, normal, radius, step)
          best = chain if chain && (best.nil? || chain.runs.length > best.runs.length)
        end
      end
      best
    end

    def self.grow(entities, runs, center, normal, radius, step)
      used = {}
      runs.each { |r| r.edges.each { |e| used[e] = true } }
      closed = false
      loop do
        if runs.last.b == runs.first.a
          closed = true
          break
        end
        break if runs.length > MAX_RUNS
        run = next_run(runs.last.b, used, center, normal, radius, step)
        break unless run
        run.edges.each { |e| used[e] = true }
        runs << run
      end
      unless closed
        loop do
          break if runs.length > MAX_RUNS
          run = next_run(runs.first.a, used, center, normal, radius, -step)
          break unless run
          run.edges.each { |e| used[e] = true }
          runs.unshift(run.reverse)
        end
      end
      return nil if runs.length < (closed ? MIN_CIRCLE : MIN_ARC)
      chain = Chain.new(entities, runs, closed, center, normal, radius, step)
      refine(chain)
      chain
    end

    # Center and radius from three corners spread along the chain.
    def self.refine(chain)
      c = chain.corners
      n = c.length
      picks = chain.closed ? [c[0], c[n / 3], c[2 * n / 3]] : [c[0], c[n / 2], c[-1]]
      return if picks.uniq.length < 3
      circle = circumcircle(*picks.map(&:position))
      return unless circle && circle[1].dot(chain.normal) > 0
      chain.center, chain.normal, chain.radius = circle
      chain.step = if chain.closed
                     2 * Math::PI / chain.runs.length
                   else
                     sweep_of(chain, chain.runs) / chain.runs.length
                   end
    end
  end
end
