module Bubbles
  # An interactive table with a selectable row (`bubbles/table`). For a
  # static table use `Lipgloss::Table`.
  class Table < Component
    include Key::KeyMap

    record Column, title : String, width : Int32 do
      def to_json(json : JSON::Builder) : Nil
        json.object do
          json.field "title", title
          json.field "width", width
        end
      end
    end

    def initialize(columns : Array(Column) = [] of Column, rows : Array(Array(String)) = [] of Array(String), *,
                   width : Int32? = nil, height : Int32? = nil, focused : Bool? = nil,
                   header_style : Lipgloss::Style? = nil, cell_style : Lipgloss::Style? = nil,
                   selected_style : Lipgloss::Style? = nil, key_map : Hash(String, Key::Binding)? = nil)
      styles = if header_style || cell_style || selected_style
                 {header: header_style, cell: cell_style, selected: selected_style}
               end
      super("table", {columns: columns, rows: rows, width: width, height: height, focused: focused,
                      styles: styles, key_map: key_map})
    end

    def columns=(columns : Array(Column)) : Array(Column)
      configure(columns: columns)
      columns
    end

    def rows=(rows : Array(Array(String))) : Array(Array(String))
      configure(rows: rows)
      rows
    end

    def rows : Array(Array(String))
      call("rows").as_a?.try(&.map(&.as_a.map(&.as_s))) || [] of Array(String)
    end

    def cursor : Int32
      call("cursor").as_i
    end

    def cursor=(value : Int32) : Int32
      configure(cursor: value)
      value
    end

    def selected_row : Array(String)?
      call("selected_row").as_a?.try(&.map(&.as_s))
    end

    def focus : Nil
      call("focus")
    end

    def blur : Nil
      call("blur")
    end

    def focused? : Bool
      call("focused").as_bool
    end

    def move_up(n : Int32 = 1) : Nil
      call("move_up", n)
    end

    def move_down(n : Int32 = 1) : Nil
      call("move_down", n)
    end

    def goto_top : Nil
      call("goto_top")
    end

    def goto_bottom : Nil
      call("goto_bottom")
    end

    def width=(value : Int32) : Int32
      configure(width: value)
      value
    end

    def height=(value : Int32) : Int32
      configure(height: value)
      value
    end

    # The table's built-in help line.
    def help_view : String
      call("help_view").as_s
    end

    def short_help : Array(Key::Binding)
      Key.parse_help(call("help_bindings"))[0]
    end

    def full_help : Array(Array(Key::Binding))
      Key.parse_help(call("help_bindings"))[1]
    end
  end
end
