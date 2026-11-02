require "json"

module Lipgloss
  # Positions for alignment, joining and placing (0.0 = left/top,
  # 0.5 = center, 1.0 = right/bottom; any value in between works too).
  Left   = 0.0
  Top    = 0.0
  Center = 0.5
  Right  = 1.0
  Bottom = 1.0

  alias Position = Float64 | Symbol

  # :nodoc:
  def self.position(pos : Position) : Float64
    case pos
    in Float64 then pos
    in Symbol
      case pos
      when :left, :top      then 0.0
      when :center, :middle then 0.5
      when :right, :bottom  then 1.0
      else
        raise ArgumentError.new("unknown position #{pos.inspect}")
      end
    end
  end

  # A Lip Gloss style. Like in Go, styles are values: every setter returns a
  # modified copy and leaves the receiver unchanged.
  #
  # ```
  # title = Lipgloss::Style.new
  #   .bold
  #   .foreground("#FAFAFA")
  #   .background("#7D56F4")
  #   .padding(0, 1)
  # puts title.render("Hello")
  # ```
  class Style
    # JSON fragments by property name.
    protected getter props = {} of String => String
    protected getter padding_values : Array(Int32)? = nil
    protected getter margin_values : Array(Int32)? = nil
    protected getter border_spec : BorderSpec? = nil
    @json : String? = nil

    def initialize
    end

    protected def initialize(@props, @padding_values, @margin_values, @border_spec)
    end

    private def copy(props = @props.dup, padding = @padding_values, margin = @margin_values, border = @border_spec) : Style
      Style.new(props, padding, margin, border)
    end

    private def put(key : String, value) : Style
      props = @props.dup
      props[key] = value.to_json
      copy(props: props)
    end

    private def drop(key : String) : Style
      props = @props.dup
      props.delete(key)
      copy(props: props)
    end

    # --- text attributes ---------------------------------------------

    {% for attr in %w(bold italic underline strikethrough reverse blink faint
                     inline underline_spaces strikethrough_spaces color_whitespace) %}
      def {{ attr.id }}(value : Bool = true) : Style
        put({{ attr }}, value)
      end

      def unset_{{ attr.id }} : Style
        drop({{ attr }})
      end
    {% end %}

    # --- colours -----------------------------------------------------

    def foreground(color : Color) : Style
      put("foreground", color)
    end

    def background(color : Color) : Style
      put("background", color)
    end

    def unset_foreground : Style
      drop("foreground")
    end

    def unset_background : Style
      drop("background")
    end

    # --- size --------------------------------------------------------

    {% for attr in %w(width height max_width max_height tab_width) %}
      def {{ attr.id }}(value : Int) : Style
        put({{ attr }}, value.to_i32)
      end

      def unset_{{ attr.id }} : Style
        drop({{ attr }})
      end
    {% end %}

    # --- alignment ---------------------------------------------------

    # Horizontal alignment, optionally also vertical.
    def align(horizontal : Position, vertical : Position? = nil) : Style
      s = put("align", Lipgloss.position(horizontal))
      vertical ? s.align_vertical(vertical) : s
    end

    def align_horizontal(pos : Position) : Style
      put("align", Lipgloss.position(pos))
    end

    def align_vertical(pos : Position) : Style
      put("align_vertical", Lipgloss.position(pos))
    end

    # --- padding / margin (CSS shorthand: 1, 2, 3 or 4 values) ------

    def padding(*values : Int) : Style
      copy(padding: Style.expand(values.to_a.map(&.to_i32)))
    end

    def margin(*values : Int) : Style
      copy(margin: Style.expand(values.to_a.map(&.to_i32)))
    end

    {% for side, i in %w(top right bottom left) %}
      def padding_{{ side.id }}(value : Int) : Style
        v = (@padding_values || [0, 0, 0, 0]).dup
        v[{{ i }}] = value.to_i32
        copy(padding: v)
      end

      def margin_{{ side.id }}(value : Int) : Style
        v = (@margin_values || [0, 0, 0, 0]).dup
        v[{{ i }}] = value.to_i32
        copy(margin: v)
      end

      def border_{{ side.id }}(value : Bool = true) : Style
        spec = @border_spec || BorderSpec.new
        sides = (spec.sides || [true, true, true, true]).dup
        sides[{{ i }}] = value
        copy(border: spec.copy_with(sides: sides))
      end
    {% end %}

    def margin_background(color : Color) : Style
      put("margin_background", color)
    end

    def unset_padding : Style
      copy(padding: nil)
    end

    def unset_margin : Style
      copy(margin: nil)
    end

    # :nodoc:
    def self.expand(v : Array(Int32)) : Array(Int32)
      case v.size
      when 1 then [v[0], v[0], v[0], v[0]]
      when 2 then [v[0], v[1], v[0], v[1]]
      when 3 then [v[0], v[1], v[2], v[1]]
      when 4 then v
      else        raise ArgumentError.new("expected 1 to 4 values, got #{v.size}")
      end
    end

    # --- borders -----------------------------------------------------

    # Sets a border. Without sides all four are drawn; with sides they follow
    # CSS order (top, right, bottom, left) like Lip Gloss.
    #
    # Pass a `Border` for custom characters.
    #
    # ```
    # style.border(:rounded)
    # style.border(:normal, true, false) # top and bottom only
    # ```
    def border(type : BorderType | Symbol | Border = BorderType::Normal, *sides) : Style
      base = @border_spec || BorderSpec.new
      spec = case type
             in Border     then base.copy_with(chars: type)
             in BorderType then base.copy_with(type: type, chars: nil)
             in Symbol     then base.copy_with(type: BorderType.parse(type.to_s.camelcase), chars: nil)
             end
      unless sides.empty?
        list = [] of Bool
        sides.each { |b| list << b.as(Bool) }
        spec = spec.copy_with(sides: Style.expand_sides(list))
      end
      copy(border: spec)
    end

    def border_foreground(color : Color) : Style
      copy(border: (@border_spec || BorderSpec.new).copy_with(foreground: color))
    end

    def border_background(color : Color) : Style
      copy(border: (@border_spec || BorderSpec.new).copy_with(background: color))
    end

    def unset_border : Style
      copy(border: nil)
    end

    # :nodoc:
    def self.expand_sides(v : Array(Bool)) : Array(Bool)
      case v.size
      when 1 then [v[0], v[0], v[0], v[0]]
      when 2 then [v[0], v[1], v[0], v[1]]
      when 3 then [v[0], v[1], v[2], v[1]]
      when 4 then v
      else        raise ArgumentError.new("expected 1 to 4 sides, got #{v.size}")
      end
    end

    # --- misc --------------------------------------------------------

    # Transforms the text before rendering (`:upper` or `:lower`).
    def transform(kind : Symbol) : Style
      raise ArgumentError.new("transform must be :upper or :lower") unless kind.in?(:upper, :lower)
      put("transform", kind.to_s)
    end

    # Stores a string that `to_s` renders (Lip Gloss' `SetString`).
    def set_string(*parts : String) : Style
      put("value", parts.join(' '))
    end

    # Copies properties of *other* that are not set on this style (Lip Gloss'
    # `Inherit`; margins and padding are not inherited).
    def inherit(other : Style) : Style
      props = other.props.reject { |k, _| k == "value" }.merge(@props)
      copy(props: props, border: @border_spec || other.border_spec)
    end

    # --- rendering ---------------------------------------------------

    # Renders the given strings (joined by spaces) with this style.
    def render(*parts : String) : String
      text = parts.size == 1 ? parts[0] : parts.join(' ')
      json = to_json
      text_ptr = text.to_unsafe
      Tea::FFI.take!(LibTea.bt_style_render(json, json.bytesize, text_ptr, text.bytesize))
    end

    # Renders the string set with `set_string`.
    def to_s(io : IO) : Nil
      json = to_json
      io << Tea::FFI.take!(LibTea.bt_style_render(json, json.bytesize, Pointer(UInt8).null, -1))
    end

    # Width of border + margin + padding on the left and right.
    def horizontal_frame_size : Int32
      frame_sizes["horizontal"]
    end

    # Height of border + margin + padding on top and bottom.
    def vertical_frame_size : Int32
      frame_sizes["vertical"]
    end

    private def frame_sizes : Hash(String, Int32)
      json = to_json
      Hash(String, Int32).from_json(Tea::FFI.take!(LibTea.bt_style_frame_size(json, json.bytesize)))
    end

    # The JSON description sent to Go (memoised).
    def to_json : String
      @json ||= String.build do |io|
        io << '{'
        first = true
        sep = -> { first ? (first = false) : (io << ','); nil }
        @props.each do |k, v|
          sep.call
          k.to_json(io)
          io << ':' << v
        end
        if p = @padding_values
          sep.call
          io << %("padding":) << p.to_json
        end
        if m = @margin_values
          sep.call
          io << %("margin":) << m.to_json
        end
        if b = @border_spec
          sep.call
          io << %("border":) << b.to_json
        end
        io << '}'
      end
    end

    def to_json(json : JSON::Builder) : Nil
      json.raw(to_json)
    end

    def ==(other : Style) : Bool
      to_json == other.to_json
    end

    def hash(hasher)
      to_json.hash(hasher)
    end

    def inspect(io : IO) : Nil
      io << "#<Lipgloss::Style " << to_json << '>'
    end
  end
end
