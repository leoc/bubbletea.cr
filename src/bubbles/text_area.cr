module Bubbles
  # A multi-line text editor (`bubbles/textarea`).
  #
  # Style hashes (`focused_style`, `blurred_style`) take the keys `base`,
  # `cursor_line`, `cursor_line_number`, `end_of_buffer`, `line_number`,
  # `placeholder`, `prompt` and `text`.
  class TextArea < Component
    def initialize(*, placeholder : String? = nil, prompt : String? = nil, value : String? = nil,
                   width : Int32? = nil, height : Int32? = nil, char_limit : Int32? = nil,
                   max_width : Int32? = nil, max_height : Int32? = nil,
                   show_line_numbers : Bool? = nil, end_of_buffer_character : Char? = nil,
                   focused_style : Hash(String, Lipgloss::Style)? = nil,
                   blurred_style : Hash(String, Lipgloss::Style)? = nil,
                   cursor_style : Lipgloss::Style? = nil,
                   key_map : Hash(String, Key::Binding)? = nil)
      super("textarea", {placeholder: placeholder, prompt: prompt, value: value, width: width,
                         height: height, char_limit: char_limit, max_width: max_width,
                         max_height: max_height, show_line_numbers: show_line_numbers,
                         end_of_buffer_character: end_of_buffer_character.try(&.to_s),
                         focused_style: focused_style, blurred_style: blurred_style,
                         cursor_style: cursor_style, key_map: key_map})
    end

    def value : String
      call("value").as_s
    end

    def value=(value : String) : String
      call("set_value", value)
      value
    end

    def insert_string(s : String) : Nil
      call("insert_string", s)
    end

    def focus : Tea::Cmd?
      call_cmd("focus")
    end

    def blur : Nil
      call("blur")
    end

    def focused? : Bool
      call("focused").as_bool
    end

    def reset : Nil
      call("reset")
    end

    private def state : JSON::Any
      call("state")
    end

    # Cursor row (0-based).
    def line : Int32
      state["line"].as_i
    end

    # Cursor column within the line (0-based).
    def column : Int32
      state["column"].as_i
    end

    def line_count : Int32
      state["line_count"].as_i
    end

    def length : Int32
      state["length"].as_i
    end

    def width=(value : Int32) : Int32
      configure(width: value)
      value
    end

    def height=(value : Int32) : Int32
      configure(height: value)
      value
    end

    {% for m in %w(cursor_up cursor_down cursor_start cursor_end) %}
      def {{ m.id }} : Nil
        call({{ m }})
      end
    {% end %}

    def cursor=(column : Int32) : Int32
      call("set_cursor", column)
      column
    end

    def key_map : Hash(String, Key::Binding)
      call("key_map").as_h.transform_values { |b| Key::Binding.from_json(b) }
    end
  end
end
