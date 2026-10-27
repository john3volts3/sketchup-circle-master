# encoding: UTF-8
# Circle Master — menus, toolbar and commands.

require 'sketchup.rb'

module CircleMaster
  FILES = %w[settings vcb_parser chains volume fillet resegmenter circle_tool settings_dialog
             resize_dialog cylinders/detector cylinders/resizer cylinders/resize_tool].freeze

  FILES.each { |f| Sketchup.require(File.join(PLUGIN_DIR, f)) }

  def self.icon(name)
    File.join(PLUGIN_DIR, 'icons', name)
  end

  def self.activate_circle_tool
    Sketchup.active_model.select_tool(CircleTool.new)
  end

  def self.circle_tool_active?
    tools = Sketchup.active_model.tools
    tools.respond_to?(:active_tool) && tools.active_tool.is_a?(CircleTool)
  end

  def self.activate_resize_tool
    Sketchup.active_model.select_tool(ResizeTool.new)
  end

  def self.resize_tool_active?
    tools = Sketchup.active_model.tools
    tools.respond_to?(:active_tool) && tools.active_tool.is_a?(ResizeTool)
  end

  # Dialog command: resizes the cylinders whose wall is selected.
  def self.resize_selection
    model = Sketchup.active_model
    faces = model.selection.grep(Sketchup::Face)
    cylinders, rejected = Detector.from_faces(faces)
    if cylinders.empty?
      msg = 'Select the side wall of one or more straight cylinders or truncated ' \
            'cones (made with Push/Pull on a circle).'
      msg += "\n\nIgnored: #{rejected.uniq.join(', ')}." unless rejected.empty?
      UI.messagebox("#{PLUGIN_NAME} — #{msg}", MB_OK)
      return
    end

    ResizeDialog.show(cylinders, rejected)
  end

  # Input of the Resize Cylinders dialog: +mode+ ('diameter' or 'radius')
  # and +text+ in the syntax of the Measurements box. Returns false when the
  # user keeps the cones at the question (nothing changed). Raises
  # ArgumentError when nothing was changed (invalid input, segment count
  # refused); other errors abort the operation.
  def self.resize_cylinders(cylinders, rejected, mode, text)
    # The mode is the common setting: the Circle tool follows it too.
    Settings.input_mode = mode unless mode == Settings.input_mode
    change = VcbParser.parse(text)
    return false unless Resizer.confirm_cones(cylinders, change)
    count, native, welded = Resizer.resize(cylinders, change)
    status = "#{PLUGIN_NAME} — #{count} cylinder(s) resized: #{VcbParser.describe(change)}"
    status += Resizer.repair_note(native, welded)
    status += " (#{rejected.length} ignored: #{rejected.uniq.join(', ')})" unless rejected.empty?
    Sketchup.status_text = status
    puts "[#{PLUGIN_NAME}] #{status.sub("#{PLUGIN_NAME} — ", '')}"
    true
  end

  def self.show_settings
    SettingsDialog.show
  end

  # Development reload: CircleMaster.reload
  def self.reload
    verbose = $VERBOSE
    $VERBOSE = nil
    FILES.each { |f| load File.join(PLUGIN_DIR, "#{f}.rb") }
    puts "[#{PLUGIN_NAME}] Reloaded (#{FILES.size} files)"
  ensure
    $VERBOSE = verbose
  end

  unless @loaded
    cmd_circle = UI::Command.new('Circle') { activate_circle_tool }
    cmd_circle.small_icon = icon('circle_16.png')
    cmd_circle.large_icon = icon('circle_24.png')
    cmd_circle.tooltip = 'Circle (diameter)'
    cmd_circle.status_bar_text =
      'Draw a circle: diameter input by default, remembered segment count. ' \
      'With circles or arcs selected: type a new size, an increment or a segment count.'
    cmd_circle.set_validation_proc { circle_tool_active? ? MF_CHECKED : MF_UNCHECKED }

    cmd_dialog = UI::Command.new('Resize Cylinders…') { resize_selection }
    cmd_dialog.small_icon = icon('resize_dialog_16.png')
    cmd_dialog.large_icon = icon('resize_dialog_24.png')
    cmd_dialog.tooltip = 'Resize Cylinders…'
    cmd_dialog.status_bar_text =
      'Resize the selected cylinders or cones: type a new diameter or radius, +1 / -0.1, ' \
      'or 36s (segments); one-click steps from -0.3 to +0.3.'

    cmd_tool = UI::Command.new('Cylinder Resize Tool') { activate_resize_tool }
    cmd_tool.small_icon = icon('resize_tool_16.png')
    cmd_tool.large_icon = icon('resize_tool_24.png')
    cmd_tool.tooltip = 'Cylinder Resize Tool'
    cmd_tool.status_bar_text =
      'Click a cylinder wall, then type a new size (d15 = diameter, r7.5 = radius), ' \
      '+1 / -0.1 (increment) or 36s (segments).'
    cmd_tool.set_validation_proc { resize_tool_active? ? MF_CHECKED : MF_UNCHECKED }

    cmd_settings = UI::Command.new('Settings…') { show_settings }
    cmd_settings.small_icon = icon('settings_16.png')
    cmd_settings.large_icon = icon('settings_24.png')
    cmd_settings.tooltip = 'Circle Master settings'
    cmd_settings.status_bar_text =
      'Default segment count and input mode (diameter/radius).'

    menu = UI.menu('Extensions').add_submenu(PLUGIN_NAME)
    menu.add_item(cmd_circle)
    menu.add_item(cmd_dialog)
    menu.add_item(cmd_tool)
    menu.add_separator
    menu.add_item(cmd_settings)

    toolbar = UI::Toolbar.new(PLUGIN_NAME)
    toolbar.add_item(cmd_circle)
    toolbar.add_item(cmd_dialog)
    toolbar.add_item(cmd_tool)
    toolbar.add_separator
    toolbar.add_item(cmd_settings)
    if toolbar.get_last_state == TB_NEVER_SHOWN
      toolbar.show
    else
      toolbar.restore
    end

    puts "[#{PLUGIN_NAME}] v#{VERSION} loaded"
    @loaded = true
  end
end
