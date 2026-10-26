# encoding: UTF-8
# Detection of straight cylinders from their side wall.
#
# A cylinder is a surface (faces joined by soft edges, as created by
# Push/Pull on a circle) bounded by exactly two closed circular loops of
# hard edges. The loops may be native circles (ArcCurve) or exploded
# circles (plain edges), detected geometrically as in Re-Cercle.
#
# Truncated cones (two coaxial circles of different radii) are detected too;
# pointed cones (a single circle and an apex) are rejected.
#
# All positions are in the coordinates of the active context.

module CircleMaster
  module Detector
    MIN_SEGMENTS = 6
    BASE_TOL     = 0.001 # inches, SketchUp internal tolerance
    REL_TOL      = 0.005 # relative to the radius

    # One end circle of a cylinder.
    #   vertices: ordered, unique; arc: ArcCurve or nil (exploded circle)
    Loop = Struct.new(:edges, :vertices, :center, :normal, :radius, :arc)

    Cylinder = Struct.new(:faces, :loops) do
      def radius
        loops.first.radius
      end

      # True when the two end circles have different radii (truncated cone).
      def cone?
        a, b = loops.map(&:radius)
        (a - b).abs > Detector.tolerance([a, b].max)
      end

      def valid?
        faces.all?(&:valid?) && loops.all? { |l| l.vertices.all?(&:valid?) }
      end

      # Segment count of the first end circle: its ArcCurve's, else the
      # number of polygon corners (split points left by a solid operation do
      # not count).
      def segments
        loop = loops.first
        return loop.arc.count_edges if loop.arc
        chain = Chains.chain_from(loop.edges.first)
        chain && chain.closed ? chain.runs.length : loop.edges.length
      end
    end

    # Returns [cylinders, rejected] where rejected is a list of reasons.
    def self.from_faces(faces)
      cylinders = []
      rejected = []
      visited = {}
      faces.each do |face|
        next if visited[face]
        surface = surface_of(face)
        surface.each { |f| visited[f] = true }
        cyl, reason = build(surface)
        if cyl
          cylinders << cyl
        else
          rejected << reason
        end
      end
      [cylinders, rejected]
    end

    # Cylinder containing +face+, or nil.
    def self.from_face(face)
      cyl, _reason = build(surface_of(face))
      cyl
    end

    # Cylinder whose end loop contains +vertex+ (used to find a cylinder
    # again after SketchUp recreated its faces), or nil.
    def self.from_vertex(vertex)
      return nil unless vertex.valid?
      vertex.faces.each do |face|
        cyl = from_face(face)
        next unless cyl
        return cyl if cyl.loops.any? { |l| l.vertices.include?(vertex) }
      end
      nil
    end

    # --- Internals -----------------------------------------------------------

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

    def self.build(faces)
      return [nil, 'not a curved surface'] if faces.length < MIN_SEGMENTS
      face_set = {}
      faces.each { |f| face_set[f] = true }
      boundary = faces.flat_map(&:edges).uniq.select do |e|
        !e.soft? && e.faces.count { |f| face_set[f] } == 1
      end
      loops = build_loops(boundary)
      return [nil, 'open or branching boundary'] unless loops
      return [nil, 'pointed cone not supported'] if pointed_cone?(faces, loops)
      return [nil, "#{loops.length} boundary loop(s) instead of 2"] unless loops.length == 2

      circles = loops.map { |edges, vertices| fit_circle(edges, vertices) }
      return [nil, 'end is not a circle'] if circles.include?(nil)
      return [nil, 'not a straight cylinder or cone'] unless coaxial?(circles[0], circles[1])
      cyl = Cylinder.new(faces, circles)
      # A cone wall must only join its two end circles (rejects spheres,
      # domes... cut between two coaxial circles).
      return [nil, 'not a straight cone'] if cyl.cone? && !only_end_vertices?(faces, circles)
      [cyl, nil]
    end

    # One circular boundary loop and one vertex shared by every face.
    def self.pointed_cone?(faces, loops)
      return false unless loops.length == 1
      return false unless fit_circle(*loops.first)
      !faces.map(&:vertices).inject(:&).empty?
    end

    def self.only_end_vertices?(faces, circles)
      ends = {}
      circles.each { |c| c.vertices.each { |v| ends[v] = true } }
      faces.all? { |f| f.vertices.all? { |v| ends[v] } }
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
        return Loop.new(edges, vertices, curve.center, curve.normal.normalize,
                        curve.radius.to_f, curve)
      end

      # Broken circle: chain detection first (Re-Cercle: split points left by
      # a solid operation accepted), else the mean of the vertices.
      chain = Chains.chain_from(edges.first)
      if chain && chain.closed && chain.edges.length == edges.length
        loop_set = {}
        edges.each { |e| loop_set[e] = true }
        if chain.edges.all? { |e| loop_set[e] }
          return Loop.new(edges, vertices, chain.center, chain.normal, chain.radius, nil)
        end
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

      normal = newell_normal(pts, center)
      return nil unless normal
      return nil if pts.any? { |p| center.vector_to(p).dot(normal).abs > tol }
      Loop.new(edges, vertices, center, normal, radius, nil)
    end

    def self.newell_normal(pts, center)
      normal = Geom::Vector3d.new(0, 0, 0)
      pts.each_with_index do |p, i|
        q = pts[(i + 1) % pts.length]
        normal += center.vector_to(p).cross(center.vector_to(q))
      end
      return nil if normal.length.to_f < 1e-9
      normal.normalize
    end

    # Parallel circles whose centers lie on their common axis (straight
    # cylinder when the radii are equal, truncated cone otherwise).
    def self.coaxial?(a, b)
      tol = tolerance([a.radius, b.radius].max)
      return false unless a.normal.parallel?(b.normal)
      axis = a.center.vector_to(b.center)
      return true if axis.length.to_f < tol # degenerate, zero height
      axis.normalize.cross(a.normal).length.to_f < 0.01
    end

    def self.tolerance(radius)
      [BASE_TOL, radius * REL_TOL].max
    end
  end
end
