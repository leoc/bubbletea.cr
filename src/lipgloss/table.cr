require "json"

module Lipgloss
  # A table from `lipgloss/table`. Setters return `self` like in Go.
  #
  # ```
  # table = Lipgloss::Table.new
  #   .border(:rounded)
  #   .headers("Language", "Formal")
  #   .row("German", "Guten Tag")
  #   .style_func { |row, col| row == Lipgloss::Table::HEADER_ROW ? header : cell }
  # puts table
  # ```
  class Table
    # Row index passed to the style function for the header row.
    HEADER_ROW = -1

    getter headers = [] of String
    getter rows = [] of Array(String)
    @border : BorderSpec? = nil
    @border_style : Style? = nil
    @flags = {} of String => Bool
    @width = 0
    @height = 0
    @offset = 0
    @wrap : Bool? = nil
    @style_func : Proc(Int32, Int32, Style?)? = nil

    def headers(*headers : String) : self
      @headers = headers.to_a
      self
    end

    def headers(headers : Array(String)) : self
      @headers = headers
      self
    end

    def row(*cells : String) : self
      @rows << cells.to_a
      self
    end

    def rows(rows : Array(Array(String))) : self
      @rows.concat(rows)
      self
    end

    def clear_rows : self
      @rows.clear
      self
    end

    def border(type : BorderType | Symbol = BorderType::Normal) : self
      type = BorderType.parse(type.to_s.camelcase) if type.is_a?(Symbol)
      @border = BorderSpec.new(type)
      self
    end

    def border(chars : Border) : self
      @border = BorderSpec.new(chars: chars)
      self
    end

    def border_style(style : Style) : self
      @border_style = style
      self
    end

    {% for flag in %w(top bottom left right header column row) %}
      def border_{{ flag.id }}(value : Bool = true) : self
        @flags["border_{{ flag.id }}"] = value
        self
      end
    {% end %}

    def width(w : Int) : self
      @width = w.to_i32
      self
    end

    def height(h : Int) : self
      @height = h.to_i32
      self
    end

    def offset(o : Int) : self
      @offset = o.to_i32
      self
    end

    def wrap(value : Bool = true) : self
      @wrap = value
      self
    end

    # Style per cell; *row* is `HEADER_ROW` for headers, *col* starts at 0.
    # Evaluated in Crystal for every cell when rendering.
    def style_func(&block : Int32, Int32 -> Style?) : self
      @style_func = block
      self
    end

    def render : String
      json = to_json
      Tea::FFI.take!(LibTea.bt_lipgloss_table(json, json.bytesize))
    end

    def to_s(io : IO) : Nil
      io << render
    end

    def to_json : String
      styles = [] of String
      index = {} of String => Int32
      cells = [] of Array(Int32)
      if fn = @style_func
        cols = Math.max(@headers.size, @rows.max_of?(&.size) || 0)
        (-1...@rows.size).each do |r|
          cells << (0...cols).map do |c|
            if s = fn.call(r, c)
              j = s.to_json
              index[j] ||= (styles << j; styles.size - 1)
            else
              -1
            end
          end
        end
      end
      JSON.build do |j|
        j.object do
          j.field "headers", @headers
          j.field "rows", @rows
          j.field "border", @border if @border
          j.field "border_style", @border_style if @border_style
          @flags.each { |k, v| j.field k, v }
          j.field "width", @width
          j.field "height", @height
          j.field "offset", @offset
          j.field "wrap", @wrap unless @wrap.nil?
          unless cells.empty?
            j.field "styles" { j.array { styles.each { |s| j.raw(s) } } }
            j.field "cell_styles", cells
          end
        end
      end
    end
  end
end
