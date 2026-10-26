# encoding: UTF-8
# Circle Master — menus, toolbar and commands.

require 'sketchup.rb'

module CircleMaster
  FILES = %w[settings].freeze

  FILES.each { |f| Sketchup.require(File.join(PLUGIN_DIR, f)) }

  def self.icon(name)
    File.join(PLUGIN_DIR, 'icons', name)
  end

  # Commands whose code is not ported yet (construction of 1.0.0).
  def self.not_available(command)
    msg = "#{command}: not available yet"
    Sketchup.status_text = "#{PLUGIN_NAME} — #{msg}"
    puts "[#{PLUGIN_NAME}] #{msg}"
  end

  def self.activate_circle_tool
    not_available('Circle')
  end

  def self.resize_selection
    not_available('Resize Cylinders…')
  end

  def self.activate_resize_tool
    not_available('Cylinder Resize Tool')
  end

  def self.show_settings
    not_available('Settings…')
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

    cmd_dialog = UI::Command.new('Resize Cylinders…') { resize_selection }
    cmd_dialog.small_icon = icon('resize_dialog_16.png')
    cmd_dialog.large_icon = icon('resize_dialog_24.png')
    cmd_dialog.tooltip = 'Resize Cylinders…'
    cmd_dialog.status_bar_text =
      'Resize the selected cylinders or cones: type a new diameter or radius, or +1 / -0.1.'

    cmd_tool = UI::Command.new('Cylinder Resize Tool') { activate_resize_tool }
    cmd_tool.small_icon = icon('resize_tool_16.png')
    cmd_tool.large_icon = icon('resize_tool_24.png')
    cmd_tool.tooltip = 'Cylinder Resize Tool'
    cmd_tool.status_bar_text =
      'Click a cylinder wall, then type 15 (diameter), r7.5 (radius) or +1 / -0.1 (increment).'

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
