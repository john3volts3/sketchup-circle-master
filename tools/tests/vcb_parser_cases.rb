# encoding: UTF-8
# Cases of the single input parser (CircleMaster::VcbParser): syntax of
# Circle Advanced and of Cylinder Resize, size helpers.
#
# Outside SketchUp: ruby tools/tests/vcb_parser_cases.rb
#   Sketchup and String#to_l are simulated (model in millimetres; to_l
#   accepts only the simulated decimal separator of the PC); the cases run
#   twice, on a PC with a decimal comma, then with a decimal point. The
#   plugin files are loaded from the repository.
# Inside SketchUp (test battery), with the plugin loaded:
#   CircleMasterTests::VcbParserCases.run -> [passed, failed, report lines]
#   uses the real to_l: the model must be in millimetres.
# The input mode is switched in memory only, never written to the
# preferences.

module CircleMasterTests
  module VcbParserCases
    OFFLINE = !defined?(::Sketchup)
  end
end

if CircleMasterTests::VcbParserCases::OFFLINE
  module Sketchup
    def self.read_default(_section, _key, default = nil)
      default
    end

    def self.write_default(*_args)
      raise 'write_default must not be called by the parser cases'
    end

    # Simulated format of a model in millimetres.
    def self.format_length(length)
      mm = (length.to_f * 25.4).round(4)
      "#{mm == mm.round ? mm.round : mm}mm"
    end

    # Simulated decimal separator of the PC (set by the offline run).
    module RegionalSettings
      @separator = ','
      class << self
        attr_writer :separator

        def decimal_separator
          @separator
        end
      end
    end
  end

  class String
    # Simulated String#to_l of a model in millimetres: like the real one, it
    # accepts only the decimal separator of the PC.
    def to_l
      units = { nil => 1 / 25.4, 'mm' => 1 / 25.4, 'cm' => 10 / 25.4, 'm' => 1000 / 25.4,
                '"' => 1.0, 'in' => 1.0, "'" => 12.0, 'ft' => 12.0, 'yd' => 36.0 }
      sep = Regexp.escape(Sketchup::RegionalSettings.decimal_separator)
      num = "(\\d+(?:#{sep}\\d*)?|#{sep}\\d+)"
      value = ->(t) { t.sub(Sketchup::RegionalSettings.decimal_separator, '.').to_f }
      s = strip
      if (m = /\A#{num}'\s*#{num}"\z/.match(s))
        return value.call(m[1]) * 12.0 + value.call(m[2])
      end
      m = /\A#{num}\s*(mm|cm|m|in|ft|yd|"|')?\z/.match(s)
      raise ArgumentError, "Cannot convert \"#{s}\" to Length" unless m
      value.call(m[1]) * units[m[2]]
    end
  end

  root = File.expand_path('../../../circle_master', __FILE__)
  %w[settings vcb_parser].each { |f| load File.join(root, "#{f}.rb") }
end

module CircleMasterTests
  module VcbParserCases
    MM  = 1 / 25.4
    TOL = 1e-9
    FIELDS = [:length, :kind, :segments, :bare_integer, :sign].freeze
    D = 'diameter'.freeze
    R = 'radius'.freeze

    # [input, expected fields]: length in mm, absent fields are nil.
    PARSE = [
      # Circle Advanced (FSD 2.3, 2.6)
      ['50',          length: 50, kind: :default, bare_integer: 50],
      ['50mm',        length: 50, kind: :default],
      ['5cm',         length: 50, kind: :default],
      ["2'6\"",       length: 762, kind: :default],
      ["2'",          length: 609.6, kind: :default],
      ['3yd',         length: 2743.2, kind: :default],
      ['25r',         length: 25, kind: :radius],
      ['r25',         length: 25, kind: :radius],
      ['R25',         length: 25, kind: :radius],
      ['25mm r',      length: 25, kind: :radius],
      ['50d',         length: 50, kind: :diameter],
      ['d50',         length: 50, kind: :diameter],
      ['48s',         segments: 48],
      ['s48',         segments: 48],
      ['48 S',        segments: 48],
      ['50;36s',      length: 50, kind: :default, segments: 36, bare_integer: 50],
      ['36s;50mm',    length: 50, kind: :default, segments: 36],
      ['50 ; 36 s',   length: 50, kind: :default, segments: 36, bare_integer: 50],
      ['50mm; 48s',   length: 50, kind: :default, segments: 48],
      ['~ 50mm; 48s', length: 50, kind: :default, segments: 48],
      ['~50mm',       length: 50, kind: :default],
      ['+5',          length: 5, kind: :default, sign: 1],
      ['-2,5',        length: 2.5, kind: :default, sign: -1],
      ['-2.5',        length: 2.5, kind: :default, sign: -1],
      ['- 3',         length: 3, kind: :default, sign: -1],
      ['+d5',         length: 5, kind: :diameter, sign: 1],
      ['+r1',         length: 1, kind: :radius, sign: 1],
      ['-0.5r',       length: 0.5, kind: :radius, sign: -1],
      ['--5',         length: 5, kind: :default, sign: 1],
      ['--r1',        length: 1, kind: :radius, sign: 1],
      ['+5;36s',      length: 5, kind: :default, segments: 36, sign: 1],
      ['50;60',       length: 60, kind: :default, bare_integer: 60], # last value wins
      # Cylinder Resize (FSD, VCB and dialog)
      ['15',          length: 15, kind: :default, bare_integer: 15],
      ['d15',         length: 15, kind: :diameter],
      ['15d',         length: 15, kind: :diameter],
      ['r7.5',        length: 7.5, kind: :radius],
      ['7.5r',        length: 7.5, kind: :radius],
      ['+1',          length: 1, kind: :default, sign: 1],
      ['-0,1',        length: 0.1, kind: :default, sign: -1],
      ['+d1',         length: 1, kind: :diameter, sign: 1],
      ['+r0.5',       length: 0.5, kind: :radius, sign: 1],
      ['-0.5r',       length: 0.5, kind: :radius, sign: -1],
      ['--1',         length: 1, kind: :default, sign: 1],
      ['--3',         length: 3, kind: :default, sign: 1],
      # Decimal point or comma, whatever the separator of the PC
      ['7,5r',        length: 7.5, kind: :radius],
      ['r7,5',        length: 7.5, kind: :radius],
      ['+0,5',        length: 0.5, kind: :default, sign: 1],
      ['+r0,5',       length: 0.5, kind: :radius, sign: 1]
    ].freeze

    # [input, error message]
    PARSE_ERRORS = [
      ['',      'Empty input'],
      ['   ',   'Empty input'],
      [';',     'Empty input'],
      ['; ;',   'Empty input'],
      ['abc',   'Invalid value: abc'],
      ['5x',    'Invalid value: 5x'],
      # The message shows the text as typed. ("7,5x" is not refused: the
      # real to_l ignores the trailing letter.)
      ['x7.5',  'Invalid value: x7.5'],
      ['r',     'Invalid value: r'],
      ['0',     'Value must be positive: 0'],
      ['-0',    'Value must be positive: 0'],
      ['+48s',  'The segment count cannot be an increment'],
      ['--48s', 'The segment count cannot be an increment']
    ].freeze

    # [input, input mode, radius in mm (nil: no length)]
    RADIUS = [
      ['15',   D, 7.5],
      ['15',   R, 15],
      ['r7.5', D, 7.5],
      ['r7.5', R, 7.5],
      ['d15',  R, 7.5],
      ['+1',   D, 0.5],
      ['48s',  D, nil]
    ].freeze

    # [input, input mode, current radius in mm, target radius in mm, nil
    # (no length) or error message]
    TARGET = [
      ['15',   D, 5, 7.5],
      ['15',   R, 5, 15],
      ['+1',   D, 5, 5.5],
      ['+1',   R, 5, 6],
      ['+r1',  D, 5, 6],
      ['+d1',  R, 5, 5.5],
      ['-0,1', D, 5, 4.95],
      ['--1',  D, 5, 5.5],
      ['48s',  D, 5, nil],
      ['-10',  D, 5, 'The resulting size would be zero or negative'],
      ['-20',  D, 5, 'The resulting size would be zero or negative'],
      ['-r6',  D, 5, 'The resulting size would be zero or negative']
    ].freeze

    # [input, input mode, prefix (nil: no length), sign, length in mm,
    # segment count]
    DESCRIBE = [
      ['15',       D, 'Ø', '',  15],
      ['15',       R, 'R', '',  15],
      ['d15',      R, 'Ø', '',  15],
      ['+1',       D, 'Ø', '+', 1],
      ['-0.1r',    D, 'R', '-', 0.1],
      ['--r1',     D, 'R', '+', 1],
      ['36s',      D, nil, '',  nil, 36],
      ['15;36s',   D, 'Ø', '',  15, 36],
      ['+0,2;48s', D, 'Ø', '+', 0.2, 48]
    ].freeze

    def self.parser
      CircleMaster::VcbParser
    end

    # Runs the block with the input mode set in memory only.
    def self.with_mode(mode)
      settings = CircleMaster::Settings
      saved = settings.instance_variable_get(:@input_mode)
      settings.instance_variable_set(:@input_mode, mode)
      yield
    ensure
      settings.instance_variable_set(:@input_mode, saved)
    end

    def self.close?(got_inches, want_mm)
      (got_inches.to_f - want_mm * MM).abs < TOL
    end

    # nil when +res+ has the +want+ fields, else the differences.
    def self.field_errors(res, want)
      bad = FIELDS.reject do |f|
        w = want[f]
        g = res[f]
        if w.nil? then g.nil?
        elsif f == :length then !g.nil? && close?(g, w)
        else g == w
        end
      end
      return nil if bad.empty?
      bad.map do |f|
        g = res[f]
        g = (g.to_f / MM).round(6) if f == :length && g
        "#{f}=#{g.inspect} (want #{want[f].inspect})"
      end.join(', ')
    end

    # Error message raised by the block, or nil.
    def self.error_of
      yield
      nil
    rescue ArgumentError => e
      e.message
    end

    # Yards are a unit of String#to_l since SketchUp 2020 only.
    def self.yards?
      return true if OFFLINE
      '1yd'.to_l
      true
    rescue ArgumentError
      false
    end

    def self.run
      lines = []
      check = lambda do |name, error|
        lines << "#{error ? 'FAIL' : 'OK  '} #{name}#{error ? " -> #{error}" : ''}"
      end

      PARSE.each do |input, want|
        if input =~ /yd\z/i && !yards?
          lines << "SKIP parse #{input.inspect} (yards unknown to String#to_l of this SketchUp)"
          next
        end
        res = nil
        err = error_of { res = parser.parse(input) }
        check.call("parse #{input.inspect}", err ? "error #{err}" : field_errors(res, want))
      end
      PARSE_ERRORS.each do |input, msg|
        err = error_of { parser.parse(input) }
        check.call("parse #{input.inspect} refused", err == msg ? nil : "got #{err.inspect}")
      end
      RADIUS.each do |input, mode, want|
        got = nil
        err = with_mode(mode) { error_of { got = parser.radius_from(parser.parse(input)) } }
        ok = want.nil? ? got.nil? : (!got.nil? && close?(got, want))
        got_mm = got && (got / MM).round(6)
        name = "radius_from #{input.inspect} (#{mode})"
        check.call(name, err ? "error #{err}" : (ok ? nil : "got #{got_mm.inspect} mm"))
      end
      TARGET.each do |input, mode, current, want|
        got = nil
        err = with_mode(mode) do
          error_of { got = parser.target_radius(parser.parse(input), current * MM) }
        end
        name = "target_radius #{input.inspect} from r#{current} (#{mode})"
        if want.is_a?(String)
          check.call(name, err == want ? nil : "got #{err ? err.inspect : got}")
        elsif err
          check.call(name, "error #{err}")
        else
          ok = want.nil? ? got.nil? : (!got.nil? && close?(got, want))
          check.call(name, ok ? nil : "got #{got && (got / MM).round(6)} mm")
        end
      end
      DESCRIBE.each do |input, mode, prefix, sign, mm, segments|
        size = prefix ? "#{prefix} #{sign}#{Sketchup.format_length(mm * MM)}" : nil
        want = [size, segments ? "#{segments}s" : nil].compact.join('; ')
        got = nil
        err = with_mode(mode) { error_of { got = parser.describe(parser.parse(input)) } }
        name = "describe #{input.inspect} (#{mode})"
        check.call(name, err ? "error #{err}" : (got == want ? nil : "got #{got.inspect}, want #{want.inspect}"))
      end

      failed = lines.count { |l| l.start_with?('FAIL') }
      skipped = lines.count { |l| l.start_with?('SKIP') }
      [lines.size - failed - skipped, failed, lines]
    end
  end
end

# Outside SketchUp: on a PC with a decimal comma, then with a decimal point.
if CircleMasterTests::VcbParserCases::OFFLINE
  total_failed = 0
  [',', '.'].each do |sep|
    Sketchup::RegionalSettings.separator = sep
    passed, failed, lines = CircleMasterTests::VcbParserCases.run
    puts "--- decimal separator #{sep.inspect}"
    puts lines
    puts "#{passed} passed, #{failed} failed (decimal separator #{sep.inspect})"
    total_failed += failed
  end
  exit(total_failed.zero? ? 0 : 1)
end
