# encoding: UTF-8
# Interactive tool: hover highlights a cylinder, click picks it (Shift or
# Ctrl click adds/removes), then type the new size in the Measurements box:
#   d15 = diameter, r7.5 = radius, +1 / -0.1 = increment; a value without
#   marker (15) follows the common input mode (Settings).
# The tool stays active; typing again re-applies to the same cylinders.
# Truncated cones are shown in another color: an absolute value turns them
# into cylinders (after confirmation), an increment keeps them cones.

module CircleMaster
  class ResizeTool
    COLOR_HOVER    = Sketchup::Color.new(255, 140, 0)
    COLOR_SELECTED = Sketchup::Color.new(0, 120, 255)
    COLOR_CONE_HOVER    = Sketchup::Color.new(230, 0, 180)
    COLOR_CONE_SELECTED = Sketchup::Color.new(150, 0, 230)

    # Arrow + cylinder cursor: shows at a glance that the tool is still
    # active (clicks pick cylinders instead of selecting normally).
    def self.cursor_id
      @cursor_id ||= UI.create_cursor(
        File.join(PLUGIN_DIR, 'icons', 'cursor_resize.png'), 1, 1
      )
    end

    # --- Tool interface ----------------------------------------------------

    def activate
      @hover = nil
      @hover_face = nil
      # Cylinders already selected become the initial targets.
      faces = Sketchup.active_model.selection.grep(Sketchup::Face)
      @targets, _rejected = Detector.from_faces(faces)
      sync_selection
      update_ui
      Sketchup.active_model.active_view.invalidate
    end

    def deactivate(view)
      view.invalidate
    end

    def resume(view)
      update_ui
      view.invalidate
    end

    def onCancel(_reason, view)
      @targets = []
      sync_selection
      update_ui
      view.invalidate
    end

    def enableVCB?
      true
    end

    def onSetCursor
      UI.set_cursor(ResizeTool.cursor_id)
    end

    def onMouseMove(_flags, x, y, view)
      face = pick_face(view, x, y)
      if face != @hover_face
        @hover_face = face
        @hover = face ? Detector.from_face(face) : nil
        view.invalidate
      end
      view.tooltip = @hover ? size_text(@hover) : ''
    end

    def onLButtonDown(flags, _x, _y, view)
      additive = (flags & (CONSTRAIN_MODIFIER_MASK | COPY_MODIFIER_MASK)) != 0
      if @hover
        existing = @targets.find { |c| same_cylinder?(c, @hover) }
        if additive
          existing ? @targets.delete(existing) : @targets << @hover
        else
          @targets = [@hover]
        end
      elsif !additive
        @targets = []
      end
      sync_selection
      update_ui
      view.invalidate
    end

    def onUserText(text, view)
      refresh_targets
      if @targets.empty?
        UI.beep
        Sketchup.status_text = "#{PLUGIN_NAME} — Click a cylinder wall first."
        return
      end
      begin
        change = VcbParser.parse_size(text)
        return unless Resizer.confirm_cones(@targets, change)
        count, native, welded, anchors = Resizer.resize(@targets, change)
        # SketchUp recreated the faces (rebuilt cylinders have new vertices):
        # find the cylinders again.
        @targets = anchors.map { |v| Detector.from_vertex(v) }.compact
        @hover = nil
        @hover_face = nil
        sync_selection
        update_vcb
        Sketchup.status_text = "#{PLUGIN_NAME} — #{count} cylinder(s) resized: " \
                               "#{VcbParser.describe(change)}" \
                               "#{Resizer.repair_note(native, welded)}. " \
                               'Type again to adjust, or click another cylinder.'
      rescue ArgumentError => e
        UI.beep
        Sketchup.status_text = "#{PLUGIN_NAME} — #{e.message}"
      rescue => e
        UI.beep
        puts "[#{PLUGIN_NAME}] Error: #{e.message}"
        UI.messagebox("#{PLUGIN_NAME} — Error: #{e.message}", MB_OK)
      end
      view.invalidate
    end

    def draw(view)
      tr = local_to_world
      @targets.each do |c|
        next unless c.valid?
        draw_cylinder(view, c, tr, c.cone? ? COLOR_CONE_SELECTED : COLOR_SELECTED, 3)
      end
      if @hover && @hover.valid? && @targets.none? { |c| same_cylinder?(c, @hover) }
        draw_cylinder(view, @hover, tr, @hover.cone? ? COLOR_CONE_HOVER : COLOR_HOVER, 2)
      end
    end

    # --- Internals -----------------------------------------------------------

    private

    # Face under the cursor, only if it belongs to the active context.
    def pick_face(view, x, y)
      ph = view.pick_helper
      ph.do_pick(x, y)
      face = ph.picked_face
      return nil unless face
      model = Sketchup.active_model
      path = model.active_path
      context = path ? path.last.definition : model
      face.parent == context ? face : nil
    end

    def same_cylinder?(a, b)
      return false unless a.valid? && b.valid?
      (a.faces & b.faces).any?
    end

    def refresh_targets
      @targets = @targets.map do |c|
        c.valid? ? c : Detector.from_vertex(c.loops.first.vertices.first)
      end.compact
    end

    def sync_selection
      sel = Sketchup.active_model.selection
      sel.clear
      @targets.each { |c| sel.add(c.faces) if c.valid? }
    end

    # Active context -> world. Since SketchUp 2020, entities of the active
    # context use local coordinates; before, they were in world coordinates.
    def local_to_world
      model = Sketchup.active_model
      return Geom::Transformation.new unless Sketchup.version.to_i >= 20
      model.edit_transform
    end

    def draw_cylinder(view, cyl, tr, color, width)
      view.line_stipple = ''
      view.line_width = width
      view.drawing_color = color
      cyl.loops.each do |loop|
        pts = loop.vertices.map { |v| v.position.transform(tr) }
        view.draw(GL_LINE_LOOP, pts)
      end
    end

    # "Ø 15mm" for a cylinder, "Cone Ø 10mm / Ø 6mm" for a cone.
    def size_text(cyl)
      return "Ø #{Sketchup.format_length(cyl.radius * 2.0)}" unless cyl.cone?
      big, small = cyl.loops.map(&:radius).sort.reverse
      "Cone Ø #{Sketchup.format_length(big * 2.0)} / Ø #{Sketchup.format_length(small * 2.0)}"
    end

    # Shows the size in the common input mode, so that typing the value
    # shown again changes nothing.
    def update_vcb
      diameter = Settings.diameter_mode?
      Sketchup.vcb_label = diameter ? 'Diameter' : 'Radius'
      Sketchup.vcb_value =
        if @targets.empty? then ''
        else Sketchup.format_length(diameter ? @targets.first.radius * 2.0 : @targets.first.radius)
        end
    end

    def update_ui
      update_vcb
      Sketchup.status_text =
        if @targets.empty?
          "#{PLUGIN_NAME} — Click a cylinder wall (Shift/Ctrl: add). "
        else
          cones = @targets.count(&:cone?)
          syntax = Settings.diameter_mode? ? '15 or d15 = diameter, r7.5 = radius' : '7.5 or r7.5 = radius, d15 = diameter'
          text = "#{PLUGIN_NAME} — #{@targets.length} cylinder(s). Type #{syntax}, " \
                 '+1 (or --1) / -0.1 = increment, then Enter.'
          if cones > 0
            text += " WARNING: #{cones} cone(s) — a value makes them cylinders, " \
                    'an increment keeps them cones.'
          end
          text
        end
    end
  end
end
