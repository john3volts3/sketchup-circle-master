# encoding: UTF-8
# Circle Master — Circle tool with diameter input and remembered segment
# count, segment count changes of circles, cylinders and rounded corners,
# and resizing of push/pull cylinders. Brings together Circle Advanced 1.4.0
# and Cylinder Resize 0.3.0. Main loader (extension entry point).

require 'sketchup.rb'
require 'extensions.rb'

module CircleMaster
  PLUGIN_NAME = 'Circle Master'.freeze

  file = __FILE__.dup
  file.force_encoding('UTF-8') if file.respond_to?(:force_encoding)
  PLUGIN_ID  = File.basename(file, '.rb').freeze
  PLUGIN_DIR = File.join(File.dirname(file), PLUGIN_ID).freeze

  require File.join(PLUGIN_DIR, 'version')

  unless file_loaded?(__FILE__)
    ex = SketchupExtension.new(PLUGIN_NAME, File.join(PLUGIN_DIR, 'main'))
    ex.description = 'Circle tool with diameter input by default and remembered ' \
                     'segment count (48 by default); change the size or segment ' \
                     'count of circles, arcs, cylinder ends and rounded corners; ' \
                     'resize push/pull cylinders (holes, pins) by typing a new ' \
                     'diameter, radius or increment. Broken end circles are ' \
                     'rebuilt as native circles.'
    ex.version     = VERSION
    ex.creator     = 'john3volts3'
    ex.copyright   = '2026, john3volts3 — MIT License'
    Sketchup.register_extension(ex, true)
    file_loaded(__FILE__)
  end
end
