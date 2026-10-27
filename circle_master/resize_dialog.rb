# encoding: UTF-8
# Resize Cylinders dialog (UI::HtmlDialog, SketchUp 2017+): mode, value,
# segment count and step buttons (+0.05 to +0.3, -0.05 to -0.3, in
# model units), e.g. for the fits of 3D printed parts. The input is applied by
# CircleMaster.resize_cylinders, in the syntax of the Measurements box.

require 'json'

module CircleMaster
  module ResizeDialog
    # Size at the first opening; afterwards SketchUp restores the size and
    # position remembered under preferences_key (resizable dialog).
    WIDTH      = 420
    HEIGHT     = 430
    MIN_WIDTH  = 380
    MIN_HEIGHT = 360

    # Short names of UnitsOptions['LengthUnit'] (0 inches to 5 yards).
    UNIT_NAMES = %w[in ft mm cm m yd].freeze

    # Opens the dialog for +cylinders+ (detected from the selection);
    # +rejected+: reasons of the ignored faces (status bar).
    def self.show(cylinders, rejected)
      @dialog.close if @dialog && @dialog.visible?
      @dialog = create_dialog(cylinders, rejected)
      @dialog.show_modal
    end

    def self.create_dialog(cylinders, rejected)
      dlg = UI::HtmlDialog.new(
        dialog_title: "#{PLUGIN_NAME} — Resize Cylinders",
        preferences_key: 'CircleMaster_Resize',
        scrollable: true,
        resizable: true,
        width: WIDTH,
        height: HEIGHT,
        min_width: MIN_WIDTH,
        min_height: MIN_HEIGHT,
        style: UI::HtmlDialog::STYLE_DIALOG
      )
      dlg.set_file(File.join(PLUGIN_DIR, 'html', 'resize.html'))

      dlg.add_action_callback('ready') do |_ctx|
        dlg.execute_script("setValues(#{values(cylinders).to_json})")
      end

      done = false
      dlg.add_action_callback('apply') do |_ctx, mode, value, segments|
        next if done
        done = apply(dlg, cylinders, rejected, mode.to_s, input_text(value, segments))
      end

      dlg.add_action_callback('cancel') { |_ctx| dlg.close }
      dlg
    end

    # Values shown at the opening: size of the first cylinder in both modes,
    # common segment count (nil when they differ), unit of the steps.
    def self.values(cylinders)
      radius = cylinders.first.radius
      counts = cylinders.map(&:segments).uniq
      cones = cylinders.count(&:cone?)
      info = "#{cylinders.length} cylinder(s)"
      info += ", #{cones} cone(s)" if cones > 0
      {
        info: info,
        mode: Settings.input_mode,
        diameter: Sketchup.format_length(radius * 2.0),
        radius: Sketchup.format_length(radius),
        segments: counts.length == 1 ? counts.first : nil,
        unit: unit_name,
        min: Settings::MIN_SEGMENTS,
        max: Settings::MAX_SEGMENTS
      }
    end

    # Short name of the model length unit: the steps are in model units.
    def self.unit_name
      UNIT_NAMES[Sketchup.active_model.options['UnitsOptions']['LengthUnit'].to_i] || ''
    end

    # Input in the syntax of the Measurements box: the value (size, increment
    # or step) and/or the segment count, only those changed.
    def self.input_text(value, segments)
      parts = [value.to_s.strip]
      parts << "#{segments.to_s.strip}s" unless segments.to_s.strip.empty?
      parts.reject(&:empty?).join(';')
    end

    # Applies +text+ (the mode alone when empty) and closes the dialog.
    # Returns true when done; false keeps it open for another input: error
    # shown in the dialog (nothing was changed), or cones kept at the
    # question.
    def self.apply(dlg, cylinders, rejected, mode, text)
      if text.empty?
        Settings.input_mode = mode unless mode == Settings.input_mode
      elsif !CircleMaster.resize_cylinders(cylinders, rejected, mode, text)
        dlg.execute_script("showError('')")
        return false
      end
      dlg.close
      true
    rescue ArgumentError => e
      dlg.execute_script("showError(#{e.message.to_json})")
      false
    rescue => e
      # Raised during the operation: it was aborted.
      dlg.close
      puts "[#{PLUGIN_NAME}] Error: #{e.message}"
      UI.messagebox("#{PLUGIN_NAME} — Error: #{e.message}", MB_OK)
      true
    end
  end
end
