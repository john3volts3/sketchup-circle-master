# encoding: UTF-8
# Persistent settings (SketchUp registry via read_default/write_default).
# Until a setting is changed in Circle Master, it is read from the former
# plugins (Circle Advanced, Cylinder Resize); their sections are never
# written.

module CircleMaster
  module Settings
    SECTION          = 'CircleMaster'.freeze
    DEFAULT_SEGMENTS = 48
    MIN_SEGMENTS     = 3
    MAX_SEGMENTS     = 999
    MODE_DIAMETER    = 'diameter'.freeze
    MODE_RADIUS      = 'radius'.freeze
    MODES            = [MODE_DIAMETER, MODE_RADIUS].freeze
    COORD_AUTO       = 'auto'.freeze
    COORD_WORLD      = 'world'.freeze
    COORD_LOCAL      = 'local'.freeze
    COORD_MODES      = [COORD_AUTO, COORD_WORLD, COORD_LOCAL].freeze

    # Former settings, by key: [section, key] in order of priority.
    # Cylinder Resize stores its mode as 'Diameter' or 'Radius'.
    LEGACY = {
      'segments'   => [%w[CircleAdvanced segments]],
      'input_mode' => [%w[CircleAdvanced input_mode], %w[CylinderResize mode]],
      'coord_mode' => [%w[CircleAdvanced coord_mode]]
    }.freeze

    # Value of +key+ in the Circle Master section, else in the first former
    # section that has it, else +default+.
    def self.read(key, default)
      value = Sketchup.read_default(SECTION, key)
      return value unless value.nil?
      (LEGACY[key] || []).each do |section, old_key|
        value = Sketchup.read_default(section, old_key)
        return value unless value.nil?
      end
      default
    end

    def self.valid_segments?(value)
      value.is_a?(Integer) && value >= MIN_SEGMENTS && value <= MAX_SEGMENTS
    end

    # Default segment count (remembered between sessions).
    def self.segments
      @segments ||= begin
        n = read('segments', DEFAULT_SEGMENTS).to_i
        valid_segments?(n) ? n : DEFAULT_SEGMENTS
      end
    end

    def self.segments=(value)
      n = Integer(value)
      unless valid_segments?(n)
        raise ArgumentError,
              "Invalid segment count (#{MIN_SEGMENTS} to #{MAX_SEGMENTS})"
      end
      @segments = n
      Sketchup.write_default(SECTION, 'segments', n)
    end

    # How a value typed without marker is read: 'diameter' or 'radius'.
    # Shared by the Circle tool and the cylinder resizing.
    def self.input_mode
      @input_mode ||= begin
        m = read('input_mode', MODE_DIAMETER).to_s.downcase
        MODES.include?(m) ? m : MODE_DIAMETER
      end
    end

    def self.input_mode=(value)
      m = value.to_s
      raise ArgumentError, "Invalid mode: #{m}" unless MODES.include?(m)
      @input_mode = m
      Sketchup.write_default(SECTION, 'input_mode', m)
    end

    def self.diameter_mode?
      input_mode == MODE_DIAMETER
    end

    # Coordinates expected by the entities of an open group/component:
    # 'auto' (follow the transformations reported by the API), 'world'
    # (no conversion) or 'local' (convert with Model#edit_transform).
    def self.coord_mode
      @coord_mode ||= begin
        m = read('coord_mode', COORD_AUTO).to_s
        COORD_MODES.include?(m) ? m : COORD_AUTO
      end
    end

    def self.coord_mode=(value)
      m = value.to_s
      raise ArgumentError, "Invalid coordinate mode: #{m}" unless COORD_MODES.include?(m)
      @coord_mode = m
      Sketchup.write_default(SECTION, 'coord_mode', m)
    end
  end
end
