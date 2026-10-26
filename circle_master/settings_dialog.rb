# encoding: UTF-8
# Settings dialog (UI::HtmlDialog, SketchUp 2017+).

require 'json'

module CircleMaster
  module SettingsDialog
    def self.show
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        return
      end
      @dialog = create_dialog
      @dialog.show
    end

    WIDTH  = 360
    HEIGHT = 480

    def self.create_dialog
      dlg = UI::HtmlDialog.new(
        dialog_title: "#{PLUGIN_NAME} — Settings",
        preferences_key: 'CircleMaster_Settings',
        scrollable: false,
        resizable: false,
        width: WIDTH,
        height: HEIGHT,
        style: UI::HtmlDialog::STYLE_DIALOG
      )
      # The size remembered under preferences_key may predate the Advanced
      # section: force the current size.
      dlg.set_size(WIDTH, HEIGHT)
      dlg.set_file(File.join(PLUGIN_DIR, 'html', 'settings.html'))

      dlg.add_action_callback('ready') do |_ctx|
        values = {
          segments: Settings.segments,
          mode: Settings.input_mode,
          coord: Settings.coord_mode,
          min: Settings::MIN_SEGMENTS,
          max: Settings::MAX_SEGMENTS
        }
        dlg.execute_script("setValues(#{values.to_json})")
      end

      dlg.add_action_callback('save') do |_ctx, segments, mode, coord|
        next unless confirm_coord_mode(coord.to_s)
        begin
          Settings.segments = segments.to_i
          Settings.input_mode = mode
          Settings.coord_mode = coord
          refresh_active_tool
          dlg.close
        rescue ArgumentError => e
          dlg.execute_script("showError(#{e.message.to_json})")
        end
      end

      dlg.add_action_callback('cancel') { |_ctx| dlg.close }
      dlg
    end

    # Asks for confirmation when the coordinate mode changes. Returns false
    # if the user declines (nothing is saved, the dialog stays open).
    def self.confirm_coord_mode(coord)
      return true if coord == Settings.coord_mode
      msg = "Change the coordinate mode to '#{coord}'?\n\n" \
            "This setting only affects circles drawn inside an open group or " \
            "component. A wrong setting places every such circle at the wrong " \
            "location or size. Keep 'auto' unless circles drawn inside groups " \
            "are misplaced."
      UI.messagebox(msg, MB_YESNO) == IDYES
    end

    # Refreshes the VCB and the preview if the tool is active.
    def self.refresh_active_tool
      model = Sketchup.active_model
      return unless CircleMaster.circle_tool_active?
      model.tools.active_tool.resume(model.active_view)
    end
  end
end
