# encoding: UTF-8
# Parsing of the VCB input (Measurements box) and of the Resize Cylinders
# dialog value. Single parser of Circle Master: syntax of Circle Advanced,
# size helpers of Cylinder Resize.
#
# Syntax (several values separated by ';'):
#   50, 50mm, 2'      value without marker (diameter by default, see Settings)
#   25r, r25, 25mm r  radius
#   50d, d50          explicit diameter
#   48s, s48          segment count
#   50;36s            diameter + segments
#   +5, -2.5, +r1     increment of the size of an existing circle or cylinder
#                     ("--5" = "+5", when "+" is taken by a shortcut)
# Decimal point or comma, whatever the decimal separator of the PC.
# The cylinder resizing takes a size only (parse_size): no segment count.

module CircleMaster
  module VcbParser
    EPSILON = 1e-6 # inches

    # kind: :radius, :diameter or :default (value without marker)
    # bare_integer: integer typed alone without unit (e.g. "48"), else nil
    # sign: nil for an absolute value, +1 or -1 for an increment
    Result = Struct.new(:length, :kind, :segments, :bare_integer, :sign) do
      def delta?
        !sign.nil?
      end
    end

    SEGMENTS_RE = /\A(?:(\d+)\s*s|s\s*(\d+))\z/i
    RADIUS_RE   = /\A(?:r\s*(.+)|(.+?)\s*r)\z/i
    DIAM_RE     = /\A(?:d\s*(.+)|(.+?)\s*d)\z/i
    SIGN_RE     = /\A([+-])\s*(.+)\z/
    PLUS_ALT_RE = /\A--\s*(.+)\z/

    def self.parse(text)
      tokens = text.to_s.split(';').map(&:strip).reject(&:empty?)
      raise ArgumentError, 'Empty input' if tokens.empty?

      result = Result.new
      tokens.each do |token|
        # "~ " marks an approximate value in Sketchup.format_length.
        sign, token = split_sign(token.sub(/\A~\s*/, ''))
        if (m = SEGMENTS_RE.match(token))
          raise ArgumentError, 'The segment count cannot be an increment' if sign
          result.segments = (m[1] || m[2]).to_i
        elsif (m = RADIUS_RE.match(token))
          result.length = to_length(m[1] || m[2])
          result.kind = :radius
          result.sign = sign
        elsif token !~ /yd\z/i && (m = DIAM_RE.match(token))
          # "yd" (yards) is a unit, not a diameter marker.
          result.length = to_length(m[1] || m[2])
          result.kind = :diameter
          result.sign = sign
        else
          result.length = to_length(token)
          result.kind = :default
          result.sign = sign
          result.bare_integer = token.to_i if sign.nil? && token =~ /\A\d+\z/
        end
      end
      result
    end

    # Size input of the cylinder resizing (VCB of the tool, dialog value):
    # as parse, without segment count.
    def self.parse_size(text)
      result = parse(text)
      raise ArgumentError, 'Changing the segment count is not supported' if result.segments
      result
    end

    # Splits a leading sign: returns [nil, token] for an absolute value,
    # [+1 or -1, rest] for an increment.
    def self.split_sign(token)
      if (m = PLUS_ALT_RE.match(token))
        [1, m[1].strip]
      elsif (m = SIGN_RE.match(token))
        [m[1] == '-' ? -1 : 1, m[2].strip]
      else
        [nil, token]
      end
    end

    # A point or a comma next to a digit: decimal mark.
    DECIMAL_RE = /(?<=\d)[.,]|[.,](?=\d)/

    # +text+ with its decimal marks (point or comma) turned into the decimal
    # separator of this PC, the only one String#to_l accepts. Values are
    # separated by ';', never by ','.
    def self.local_decimals(text)
      return text unless defined?(Sketchup::RegionalSettings)
      text.gsub(DECIMAL_RE, Sketchup::RegionalSettings.decimal_separator)
    end

    # Converts a string to a Length in model units (decimal point or comma).
    def self.to_length(str)
      begin
        len = local_decimals(str.strip).to_l
      rescue ArgumentError
        raise ArgumentError, "Invalid value: #{str}"
      end
      raise ArgumentError, "Value must be positive: #{str}" unless len > 0
      len
    end

    # true when the length of +result+ is a radius: "r" marker, or no marker
    # with the input mode set to radius (Settings).
    def self.radius?(result)
      result.kind == :radius || (result.kind == :default && !Settings.diameter_mode?)
    end

    # Radius (Float, inches) from a parse result, ignoring its sign. nil when
    # no length was typed.
    def self.radius_from(result)
      return nil unless result.length
      radius?(result) ? result.length.to_f : result.length.to_f / 2.0
    end

    # New radius (Float, inches) of a circle whose radius is +current+: the
    # typed value, or +current+ plus/minus the increment. nil when no length
    # was typed.
    def self.target_radius(result, current)
      radius = radius_from(result)
      return radius unless radius && result.delta?
      radius = current + result.sign * radius
      raise ArgumentError, 'The resulting size would be zero or negative' unless radius > EPSILON
      radius
    end

    # Short text for the status bar: "Ø 15mm", "Ø +1mm", "R -0.1mm".
    def self.describe(result)
      prefix = radius?(result) ? 'R' : 'Ø'
      sign = result.delta? ? (result.sign > 0 ? '+' : '-') : ''
      "#{prefix} #{sign}#{Sketchup.format_length(result.length)}"
    end
  end
end
