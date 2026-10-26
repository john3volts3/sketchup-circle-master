# encoding: UTF-8
# Circle tool: mimics the native tool (inferences, axis locking with the
# arrow keys, click-click or click-drag, VCB input) with diameter input
# by default and a remembered segment count.
#
# Modify mode: when native circles or arcs are selected as the tool is
# activated, the VCB shows their size and typing a value (or an increment,
# +5 / -2.5) resizes them about their center. A click starts a new circle
# and leaves the mode, as does Esc.
#
# Copy mode: Ctrl pressed and released alone (or "=" typed) in modify mode
# makes the size and segment count of the first selected circle the
# template of the next circles: each click places one, created when the
# button is released, until Ctrl again or Esc.

module CircleMaster
  class CircleTool
    STATE_CENTER = 0 # picking the center
    STATE_RADIUS = 1 # center placed, picking the radius

    DRAG_THRESHOLD = 5  # pixels: beyond this, releasing the button commits the circle
    PREVIEW_PIXELS = 30 # on-screen radius of the preview before the first click
    CTRL_TAP_TIME  = 0.8  # seconds: a longer Ctrl press is not a tap

    COLOR_X     = Sketchup::Color.new(255, 0, 0)
    COLOR_Y     = Sketchup::Color.new(0, 170, 0)
    COLOR_Z     = Sketchup::Color.new(0, 0, 255)
    COLOR_OTHER = Sketchup::Color.new(0, 0, 0)
    COLOR_LINE  = Sketchup::Color.new(90, 90, 90)

    # Watches the model to forget the last circle as soon as another
    # operation (or an undo) happens: modifying it afterwards through the
    # VCB must only apply to the circle that was just drawn. In modify mode,
    # the selected circles are re-read (an undo may have resized them).
    class ModelWatcher < Sketchup::ModelObserver
      def initialize(tool)
        @tool = tool
      end

      def onTransactionCommit(_model)
        changed
      end

      def onTransactionUndo(_model)
        changed
      end

      def onTransactionRedo(_model)
        changed
      end

      private

      def changed
        @tool.cancel_ctrl_tap # Ctrl was used for a shortcut (Ctrl+Z...)
        return if @tool.own_operation?
        @tool.forget_last
        @tool.refresh_targets
      end
    end

    # Size and segment count of the previous circle ({radius:, segments:}):
    # the last circle drawn, or the circle selected when the tool was
    # activated. Kept for the SketchUp session; a double-click places one.
    class << self
      attr_accessor :previous
    end

    def self.cursor_id
      @cursor_id ||= UI.create_cursor(
        File.join(PLUGIN_DIR, 'icons', 'cursor_circle.png'), 4, 27
      )
    end

    # --- Tool interface ----------------------------------------------------

    def activate
      @ip        = Sketchup::InputPoint.new
      @ip_center = Sketchup::InputPoint.new
      @last      = nil
      @own_op    = false
      @template  = nil # copy mode: {radius:, segments:}
      @copy_at   = nil # copy mode: [center, normal] between press and release
      unlock
      reset_state
      ignored = collect_targets
      curve = modifying? ? target_curves.first : nil
      if curve
        CircleTool.previous = { radius: world_radius(curve), segments: curve.count_edges }
      end
      @watcher = ModelWatcher.new(self)
      Sketchup.active_model.add_observer(@watcher)
      update_ui
      if ignored > 0
        Sketchup.status_text = "#{ignored} selected curve(s) ignored: not a native " \
                               "circle or arc. #{Sketchup.status_text}"
      end
      Sketchup.active_model.active_view.invalidate
    end

    def deactivate(view)
      Sketchup.active_model.remove_observer(@watcher) if @watcher
      @watcher = nil
      view.invalidate
    end

    def resume(view)
      @ctrl_tap = nil
      update_ui
      view.invalidate
    end

    def onCancel(_reason, view)
      reset_state
      unlock
      leave_modify if modifying?
      @template = nil
      @copy_at = nil
      update_ui
      view.invalidate
    end

    def enableVCB?
      true
    end

    def onSetCursor
      UI.set_cursor(CircleTool.cursor_id)
    end

    def onMouseMove(_flags, x, y, view)
      if @state == STATE_CENTER
        @ip.pick(view, x, y)
      else
        @ip.pick(view, x, y, @ip_center)
        update_radius_point
      end
      view.tooltip = @ip.tooltip if @ip.valid?
      update_vcb
      view.invalidate
    end

    def onLButtonDown(_flags, x, y, view)
      @ctrl_tap = nil
      if @state == STATE_CENTER
        return unless @ip.valid?
        leave_modify if modifying?
        @last = nil
        if @template
          # Copy mode: the circle is created when the button is released.
          @copy_at = [@ip.position.clone, active_normal.clone]
        else
          @center = @ip.position.clone
          @normal = inferred_normal
          @ip_center.copy!(@ip)
          @radius_point = nil
          @down_xy = [x, y]
          @state = STATE_RADIUS
        end
      else
        commit_from_mouse
      end
      update_ui
      view.invalidate
    end

    def onLButtonUp(_flags, x, y, view)
      if @copy_at
        center, normal = @copy_at
        @copy_at = nil
        create_circle(center, normal, @template[:radius], @template[:segments])
        update_ui
        view.invalidate
        return
      end
      return unless @state == STATE_RADIUS && @down_xy
      dx = x - @down_xy[0]
      dy = y - @down_xy[1]
      @down_xy = nil
      # Click-drag-release: releasing the button commits the circle.
      commit_from_mouse if Math.sqrt(dx * dx + dy * dy) > DRAG_THRESHOLD
      update_ui
      view.invalidate
    end

    # Double-click: a circle with the size and segments of the previous one,
    # centered on the point of the first click. Ignored in copy mode (the
    # first click already placed a circle).
    def onLButtonDoubleClick(_flags, _x, _y, view)
      prev = CircleTool.previous
      return unless prev && @state == STATE_RADIUS && @center && !@template
      create_circle(@center, active_normal, prev[:radius], prev[:segments])
      update_ui
      view.invalidate
    end

    def onKeyDown(key, _repeat, _flags, view)
      if key == COPY_MODIFIER_KEY
        @ctrl_tap ||= Time.now
        return false
      end
      @ctrl_tap = nil # another key: Ctrl is part of a shortcut
      case key
      when VK_RIGHT then toggle_lock(:x)
      when VK_LEFT  then toggle_lock(:y)
      when VK_UP    then toggle_lock(:z)
      when VK_DOWN  then toggle_lock(:current)
      when CONSTRAIN_MODIFIER_KEY
        # Shift held: freeze the current orientation.
        if @locked_normal.nil?
          @locked_normal = active_normal.clone
          @lock_key = :shift
        end
      else
        return false
      end
      update_radius_point if @state == STATE_RADIUS
      view.invalidate
      true
    end

    def onKeyUp(key, _repeat, _flags, view)
      if key == COPY_MODIFIER_KEY
        tap = @ctrl_tap && Time.now - @ctrl_tap <= CTRL_TAP_TIME
        @ctrl_tap = nil
        toggle_copy(view) if tap
        return false
      end
      @ctrl_tap = nil
      return false unless key == CONSTRAIN_MODIFIER_KEY && @lock_key == :shift
      unlock
      update_radius_point if @state == STATE_RADIUS
      view.invalidate
      true
    end

    def onUserText(text, view)
      begin
        if text.strip == '='
          start_copy
        else
          res = VcbParser.parse(text)
          apply_user_input(res)
        end
      rescue ArgumentError => e
        UI.beep
        Sketchup.status_text = "#{PLUGIN_NAME} — #{e.message}"
        update_vcb
        return
      end
      update_ui
      view.invalidate
    end

    def draw(view)
      @ip.draw(view) if @ip.valid? && @ip.display?
      if @state == STATE_CENTER
        if @ip.valid?
          center = @ip.position
          if @template
            # Copy mode: preview at the real size of the circle to place.
            draw_circle(view, center, active_normal, @template[:radius], @template[:segments])
          else
            radius = view.pixels_to_model(PREVIEW_PIXELS, center)
            draw_circle(view, center, active_normal, radius)
          end
        end
      else
        view.draw_points([@center], 8, 3, COLOR_LINE)
        radius = current_radius
        if radius > 0
          draw_circle(view, @center, active_normal, radius)
          draw_radius_line(view)
        end
      end
    end

    def getExtents
      bb = Geom::BoundingBox.new
      if @state == STATE_RADIUS
        bb.add(@center)
        radius = current_radius
        bb.add(circle_points(@center, active_normal, radius)) if radius > 0
      elsif @ip && @ip.valid?
        bb.add(@ip.position)
        if @template
          bb.add(circle_points(@ip.position, active_normal, @template[:radius],
                               @template[:segments]))
        end
      end
      bb
    end

    # --- Called by the observer --------------------------------------------

    def own_operation?
      @own_op
    end

    def forget_last
      return unless @last
      @last = nil
      update_vcb
    end

    def cancel_ctrl_tap
      @ctrl_tap = nil
    end

    # Modify mode: drops the circles that no longer exist and shows the
    # current size (it may have changed through an undo or another tool).
    def refresh_targets
      return unless modifying?
      @targets.select! { |edge| arc_of(edge) }
      update_ui
    end

    private

    def reset_state
      @state        = STATE_CENTER
      @center       = nil
      @normal       = nil
      @radius_point = nil
      @down_xy      = nil
    end

    def unlock
      @locked_normal = nil
      @lock_key      = nil
    end

    # --- Orientation ---------------------------------------------------------

    # Reference axes: those of the component being edited, otherwise the
    # model drawing axes.
    def reference_axes
      model = Sketchup.active_model
      path = model.active_path
      if path && !path.empty?
        t = model.edit_transform
        [t.xaxis, t.yaxis, t.zaxis].map(&:normalize)
      else
        a = model.axes
        [a.xaxis, a.yaxis, a.zaxis]
      end
    end

    # Normal inferred from the hovered point: face normal, otherwise blue axis.
    def inferred_normal
      face = @ip.valid? ? @ip.face : nil
      if face
        n = face.normal.transform(@ip.transformation)
        return n.normalize if n.valid?
      end
      reference_axes[2].clone
    end

    # Normal actually used (lock > normal fixed at click > inference).
    def active_normal
      return @locked_normal if @locked_normal
      @state == STATE_RADIUS ? @normal : inferred_normal
    end

    def toggle_lock(kind)
      if @lock_key == kind
        unlock
        return
      end
      axes = reference_axes
      vec = case kind
            when :x then axes[0]
            when :y then axes[1]
            when :z then axes[2]
            else active_normal
            end
      @locked_normal = vec.clone.normalize
      @lock_key = kind
    end

    def color_for(normal)
      axes = reference_axes
      return COLOR_X if normal.parallel?(axes[0])
      return COLOR_Y if normal.parallel?(axes[1])
      return COLOR_Z if normal.parallel?(axes[2])
      COLOR_OTHER
    end

    # Center -> cursor line: dashed, colored and thick when it runs along
    # an axis (like the native tool), thin black otherwise.
    def draw_radius_line(view)
      direction = @center.vector_to(@radius_point)
      color = color_for(direction)
      view.line_stipple = '-'
      view.line_width = color == COLOR_OTHER ? 1 : 3
      view.drawing_color = color
      view.draw(GL_LINES, [@center, @radius_point])
      view.line_stipple = ''
    end

    # --- Geometry ----------------------------------------------------------

    def update_radius_point
      return unless @ip.valid? && @center
      @radius_point = @ip.position.project_to_plane([@center, active_normal])
    end

    def current_radius
      return 0.0 unless @center && @radius_point
      @center.distance(@radius_point)
    end

    def circle_points(center, normal, radius, n = Settings.segments)
      xaxis, yaxis = normal.axes
      (0...n).map do |i|
        a = 2.0 * Math::PI * i / n
        v = Geom::Vector3d.linear_combination(
          radius * Math.cos(a), xaxis, radius * Math.sin(a), yaxis
        )
        center.offset(v)
      end
    end

    def draw_circle(view, center, normal, radius, n = Settings.segments)
      view.line_stipple = ''
      view.line_width = @locked_normal ? 3 : 1
      view.drawing_color = color_for(normal)
      view.draw(GL_LINE_LOOP, circle_points(center, normal, radius, n))
    end

    # World -> active context transformation, as the API reports it. While an
    # instance is open for editing, SketchUp may report its transformation as
    # identity and its entities in world coordinates; using the reported
    # transformations adapts to whichever convention the running version uses.
    # The 'world' and 'local' coordinate modes (Advanced settings) force one
    # convention.
    def world_to_local(model)
      case Settings.coord_mode
      when Settings::COORD_WORLD then return Geom::Transformation.new
      when Settings::COORD_LOCAL then return model.edit_transform.inverse
      end
      path = model.active_path || []
      reported = path.inject(Geom::Transformation.new) do |t, inst|
        t * inst.transformation
      end
      reported.inverse
    end

    def commit_from_mouse
      radius = current_radius
      if radius > 0
        create_circle(@center, active_normal, radius, Settings.segments)
      else
        UI.beep
      end
    end

    # Creates the circle (native ArcCurve + face) in the active context.
    # center/normal/radius are in world coordinates.
    def create_circle(center, normal, radius, segments)
      model = Sketchup.active_model
      tr = world_to_local(model)
      local_center = center.transform(tr)
      local_normal = normal.transform(tr)
      local_normal.normalize!
      radius_vec = normal.axes[0]
      radius_vec.length = radius
      local_radius = radius_vec.transform(tr).length

      @own_op = true
      model.start_operation("#{PLUGIN_NAME} — Circle", true)
      begin
        edges = model.active_entities.add_circle(
          local_center, local_normal, local_radius, segments
        )
        edges.first.find_faces if edges && !edges.empty?
        model.commit_operation
      rescue => e
        model.abort_operation
        UI.messagebox("#{PLUGIN_NAME} — Error: #{e.message}", MB_OK)
        return false
      ensure
        @own_op = false
      end

      @last = {
        center: center.clone, normal: normal.clone,
        radius: radius, segments: segments, edges: edges
      }
      CircleTool.previous = { radius: radius, segments: segments }
      reset_state
      unlock
      true
    end

    # Modifies the last circle drawn: undoes its creation, then recreates it.
    def modify_last(radius, segments)
      last = @last
      unless last && last[:edges].all?(&:valid?)
        @last = nil
        raise ArgumentError, 'No circle to modify'
      end
      @own_op = true
      begin
        Sketchup.undo
      ensure
        @own_op = false
      end
      if last[:edges].first.valid?
        @last = nil
        raise ArgumentError, 'Cannot modify the circle (undo refused)'
      end
      create_circle(last[:center], last[:normal],
                    radius || last[:radius], segments || last[:segments])
    end

    # --- Modify mode -------------------------------------------------------

    # Native circles and arcs of the selection become the targets. One edge
    # is kept per curve: the edges survive the resize and the curve is read
    # again from them. Returns the number of non-native curves ignored.
    def collect_targets
      edges = Sketchup.active_model.selection.grep(Sketchup::Edge)
      curves = edges.map(&:curve).compact.uniq(&:entityID)
      arcs = curves.select { |c| c.is_a?(Sketchup::ArcCurve) }
      @targets = arcs.map(&:first_edge)
      curves.size - arcs.size
    end

    def modifying?
      !@targets.nil? && !@targets.empty?
    end

    # Clears the selection too, so that it no longer shows circles that
    # typing would not change.
    def leave_modify
      @targets = []
      Sketchup.active_model.selection.clear
    end

    def arc_of(edge)
      return nil unless edge.valid?
      curve = edge.curve
      curve.is_a?(Sketchup::ArcCurve) ? curve : nil
    end

    def target_curves
      @targets.map { |edge| arc_of(edge) }.compact.uniq(&:entityID)
    end

    def tolerance(radius)
      [0.001, radius * 0.005].max
    end

    # Radius shown to the user (world size), measured from the vertices and
    # converted like the drawn circles (see world_to_local).
    def world_radius(curve)
      tr = world_to_local(Sketchup.active_model).inverse
      center = curve.center.transform(tr)
      center.distance(curve.first_edge.start.position.transform(tr)).to_f
    end

    # Resizes the selected circles/arcs and/or changes their segment count
    # in one undoable operation.
    #
    # Size: each one is scaled about its center (Entities#transform_entities),
    # which keeps it a native ArcCurve with the same center; the result is
    # checked, otherwise nothing is changed. Arcs sharing a center and a
    # radius (a circle split by a line) share end vertices: they are scaled
    # together. Connected geometry follows, as with Entity Info (the end
    # circle of a cylinder makes it a truncated cone).
    #
    # Segments (after the resize): the circles are rebuilt (Resegmenter); a
    # cylinder end rebuilds the whole cylinder. The remembered default
    # segment count is not changed.
    def resize_targets(res)
      n = res.segments
      if n && !Settings.valid_segments?(n)
        raise ArgumentError, "Segments: #{Settings::MIN_SEGMENTS} to " \
                             "#{Settings::MAX_SEGMENTS}"
      end
      curves = target_curves
      raise ArgumentError, 'The selected circles no longer exist' if curves.empty?
      # Refusals are reported before anything is modified.
      resegment = n ? Resegmenter.check(curves, n) : false
      groups = res.length ? scale_groups(res, curves) : []
      return true if groups.empty? && !resegment

      model = Sketchup.active_model
      before = resegment ? curves.map { |c| target_mark(c) } : nil
      after = nil
      name = if groups.empty? then 'Circle Segments'
             elsif resegment then 'Modify Circle'
             else 'Resize Circle'
             end
      @own_op = true
      model.start_operation("#{PLUGIN_NAME} — #{name}", true)
      begin
        groups.each do |g|
          edges = g[:before].map(&:first).flatten
          model.active_entities.transform_entities(
            Geom::Transformation.scaling(g[:center], g[:scale]), edges
          )
        end
        groups.each { |g| check_group(g) }
        if resegment
          after = target_curves.map { |c| target_mark(c) }
          Resegmenter.run(model.active_entities, @targets, n)
        end
        model.commit_operation
      rescue => e
        model.abort_operation
        reselect(before) if before
        UI.messagebox("#{PLUGIN_NAME} — Error: #{e.message}", MB_OK)
        return false
      ensure
        @own_op = false
      end
      reselect(after) if after
      true
    end

    # Rebuilt circles have new edges: finds the targets again and selects
    # them.
    def reselect(marks)
      @targets = refind_targets(marks)
      sel = Sketchup.active_model.selection
      sel.clear
      target_curves.each { |c| sel.add(c.edges) }
    end

    # Groups of curves scaled together (same center, radius and normal), with
    # the scale giving the size typed. Positions, centers and curve radii are
    # used in the coordinates the API reports, as transform_entities expects.
    def scale_groups(res, curves)
      groups = []
      curves.each do |curve|
        center = curve.center
        radius = center.distance(curve.first_edge.start.position).to_f
        tol = tolerance(radius)
        group = groups.find do |g|
          g[:center].distance(center).to_f <= tol && (g[:radius] - radius).abs <= tol &&
            g[:normal].parallel?(curve.normal)
        end
        if group
          group[:curves] << curve
        else
          current = world_radius(curve)
          groups << { center: center, radius: radius, normal: curve.normal,
                      scale: VcbParser.target_radius(res, current) / current, curves: [curve] }
        end
      end
      groups.each do |g|
        g[:before] = g[:curves].map { |c| [c.edges.to_a, c.radius.to_f] }
      end
      groups
    end

    # Where a target lies (center, radius, point in the middle of the arc),
    # to find it again once its edges have been recreated.
    def target_mark(curve)
      start, sweep = Resegmenter.arc_frame(curve)
      center = curve.center.clone
      turn = Geom::Transformation.rotation(center, curve.normal, sweep / 2.0)
      [center, center.distance(start).to_f, start.transform(turn)]
    end

    # One edge per mark: the native arc edge on the marked circle closest to
    # the marked point.
    def refind_targets(marks)
      edges = Sketchup.active_model.active_entities.grep(Sketchup::Edge).select do |e|
        e.curve.is_a?(Sketchup::ArcCurve)
      end
      found = marks.map do |center, radius, point|
        tol = tolerance(radius)
        on_circle = edges.select do |e|
          e.vertices.all? { |v| (center.distance(v.position).to_f - radius).abs <= tol }
        end
        on_circle.min_by do |e|
          point.distance(Geom.linear_combination(0.5, e.start.position, 0.5, e.end.position)).to_f
        end
      end
      found.compact.uniq { |e| e.curve.entityID }
    end

    # Raises (the whole operation is then aborted) unless each arc of the
    # group is still one native ArcCurve with the same center, its radius
    # and its vertices at the expected distance.
    def check_group(group)
      radius = group[:radius] * group[:scale]
      tol = tolerance(radius)
      group[:before].each do |edges, old_radius|
        curve = arc_of(edges.first)
        expected = old_radius * group[:scale]
        on_circle = lambda do |v|
          (group[:center].distance(v.position).to_f - radius).abs <= tol
        end
        ok = curve &&
             edges.all? { |e| e.valid? && e.curve && e.curve.entityID == curve.entityID } &&
             (curve.radius.to_f - expected).abs <= tolerance(expected) &&
             curve.center.distance(group[:center]).to_f <= tol &&
             edges.all? { |e| e.vertices.all?(&on_circle) }
        raise 'A circle or arc could not be resized, nothing was changed' unless ok
      end
    end

    # --- VCB input ---------------------------------------------------------
    # Radius of a typed value and increments: VcbParser.radius_from and
    # VcbParser.target_radius.

    # Ctrl pressed and released alone: copy mode on (in modify mode, from the
    # first selected circle) or off. Ignored in the other states.
    def toggle_copy(view)
      if @template
        @template = nil
        @copy_at = nil
      elsif modifying?
        begin
          start_copy
        rescue ArgumentError => e
          UI.beep
          Sketchup.status_text = "#{PLUGIN_NAME} — #{e.message}"
          return
        end
      else
        return
      end
      update_ui
      view.invalidate
    end

    # Ctrl (or "=") in modify mode: the size and segment count of the first
    # selected circle become the template of the next circles (copy mode,
    # until Ctrl again or Esc). The remembered default segment count is not
    # changed.
    def start_copy
      curve = modifying? ? target_curves.first : nil
      raise ArgumentError, 'Copy: select a circle first' unless curve
      @template = { radius: world_radius(curve), segments: curve.count_edges }
      leave_modify
    end

    # Copy mode before a circle is placed: the input changes the template.
    def update_template(res)
      if res.segments && !Settings.valid_segments?(res.segments)
        raise ArgumentError, "Segments: #{Settings::MIN_SEGMENTS} to " \
                             "#{Settings::MAX_SEGMENTS}"
      end
      radius = VcbParser.target_radius(res, @template[:radius])
      @template = {
        radius: radius || @template[:radius],
        segments: res.segments || @template[:segments]
      }
    end

    def apply_user_input(res)
      return resize_targets(res) if modifying?
      return update_template(res) if @template && @last.nil?

      if res.delta?
        unless @state == STATE_CENTER && @last
          raise ArgumentError, 'Increment: select a circle or arc first'
        end
        VcbParser.target_radius(res, @last[:radius]) # checked before anything is saved
      end

      if res.segments
        unless Settings.valid_segments?(res.segments)
          raise ArgumentError, "Segments: #{Settings::MIN_SEGMENTS} to " \
                               "#{Settings::MAX_SEGMENTS}"
        end
        # In copy mode, segments belong to the template, not to the default.
        Settings.segments = res.segments unless @template
      end

      if @state == STATE_RADIUS
        radius = VcbParser.radius_from(res)
        create_circle(@center, active_normal, radius, Settings.segments) if radius
      elsif @last
        radius = VcbParser.target_radius(res, @last[:radius])
        modify_last(radius, res.segments) if radius || res.segments
        # Copy mode: the next circles follow the change.
        if @template && @last
          @template = { radius: @last[:radius], segments: @last[:segments] }
        end
      elsif res.bare_integer && res.kind == :default && res.segments.nil?
        # Before the first click, a plain integer sets the number of sides
        # (like the native tool).
        unless Settings.valid_segments?(res.bare_integer)
          raise ArgumentError, "Segments: #{Settings::MIN_SEGMENTS} to " \
                               "#{Settings::MAX_SEGMENTS}"
        end
        Settings.segments = res.bare_integer
      elsif res.length
        raise ArgumentError, 'Place the circle center first'
      end
    end

    # --- UI ------------------------------------------------------------------

    def mode_label
      Settings.diameter_mode? ? 'Diameter' : 'Radius'
    end

    def display_length(radius)
      value = Settings.diameter_mode? ? radius * 2.0 : radius
      Sketchup.format_length(value)
    end

    def update_vcb
      if @state == STATE_RADIUS
        Sketchup.vcb_label = mode_label
        radius = current_radius
        Sketchup.vcb_value = radius > 0 ? display_length(radius) : ''
      # Size and segments of the circle to modify, written in the input
      # syntax ("50mm; 48s"): entering the value again changes nothing.
      elsif modifying?
        curve = target_curves.first
        Sketchup.vcb_label = "#{mode_label}; Segments"
        Sketchup.vcb_value =
          curve ? "#{display_length(world_radius(curve))}; #{curve.count_edges}s" : ''
      elsif @template && @last.nil?
        Sketchup.vcb_label = "#{mode_label}; Segments"
        Sketchup.vcb_value = "#{display_length(@template[:radius])}; #{@template[:segments]}s"
      elsif @last
        Sketchup.vcb_label = "#{mode_label}; Segments"
        Sketchup.vcb_value = "#{display_length(@last[:radius])}; #{@last[:segments]}s"
      else
        Sketchup.vcb_label = 'Sides'
        Sketchup.vcb_value = Settings.segments.to_s
      end
    end

    def update_ui
      update_vcb
      Sketchup.status_text =
        if modifying?
          syntax = Settings.diameter_mode? ? '60 = diameter, 30r = radius' : '30 = radius, 60d = diameter'
          curves = target_curves
          segments = curves.empty? ? '' : " (#{curves.first.count_edges} segments)"
          "#{curves.size} circle(s)/arc(s) selected#{segments}: type #{syntax}, " \
          '+5 / -2.5 = increment (--5 = +5), 36s = segments, then Enter. ' \
          'Ctrl: copy this size to new circles. Click: new circle. Esc: stop modifying.'
        elsif @template
          "Copy: click to place a circle (#{mode_label} " \
          "#{display_length(@template[:radius])}, #{@template[:segments]} segments). " \
          'Type a value to change it. Arrows: lock the normal. Ctrl or Esc: stop copying.'
        elsif @state == STATE_CENTER
          'Click to place the center. Arrows: lock the normal ' \
          '(→ red, ← green, ↑ blue, ↓ current orientation). ' \
          'Shift: hold the orientation. Input: 48s = segments.'
        else
          syntax = Settings.diameter_mode? ? '50 = diameter, 25r = radius' : '25 = radius, 50d = diameter'
          'Click (or release) to set the size. Input: ' \
          "#{syntax}, 48s = segments, 50;36s."
        end
    end
  end
end
