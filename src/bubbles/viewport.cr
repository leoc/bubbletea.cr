module Bubbles
  # A scrollable view of a larger content (`bubbles/viewport`). Keys
  # (↑/↓/pgup/pgdown/...) and the mouse wheel scroll it when you forward
  # messages to `update`.
  class Viewport < Component
    def initialize(width : Int32 = 0, height : Int32 = 0, *, content : String? = nil,
                   style : Lipgloss::Style? = nil, mouse_wheel_enabled : Bool? = nil,
                   mouse_wheel_delta : Int32? = nil, horizontal_step : Int32? = nil,
                   key_map : Hash(String, Key::Binding)? = nil)
      super("viewport", {width: width, height: height, content: content, style: style,
                         mouse_wheel_enabled: mouse_wheel_enabled, mouse_wheel_delta: mouse_wheel_delta,
                         horizontal_step: horizontal_step, key_map: key_map})
    end

    def content=(content : String) : String
      call("set_content", content)
      content
    end

    def set_size(width : Int32, height : Int32) : Nil
      configure(width: width, height: height)
    end

    def width=(value : Int32) : Int32
      configure(width: value)
      value
    end

    def height=(value : Int32) : Int32
      configure(height: value)
      value
    end

    private def state : JSON::Any
      call("state")
    end

    def width : Int32
      state["width"].as_i
    end

    def height : Int32
      state["height"].as_i
    end

    def y_offset : Int32
      state["y_offset"].as_i
    end

    def y_offset=(value : Int32) : Int32
      call("set_y_offset", value)
      value
    end

    def x_offset=(value : Int32) : Int32
      call("set_x_offset", value)
      value
    end

    def at_top? : Bool
      state["at_top"].as_bool
    end

    def at_bottom? : Bool
      state["at_bottom"].as_bool
    end

    def past_bottom? : Bool
      state["past_bottom"].as_bool
    end

    # 0.0..1.0
    def scroll_percent : Float64
      state["scroll_percent"].as_f
    end

    def horizontal_scroll_percent : Float64
      state["horizontal_scroll_percent"].as_f
    end

    def total_line_count : Int32
      state["total_line_count"].as_i
    end

    def visible_line_count : Int32
      state["visible_line_count"].as_i
    end

    {% for m in %w(scroll_down scroll_up scroll_left scroll_right) %}
      def {{ m.id }}(n : Int32 = 1) : Nil
        call({{ m }}, n)
      end
    {% end %}

    {% for m in %w(page_down page_up half_page_down half_page_up goto_top goto_bottom) %}
      def {{ m.id }} : Nil
        call({{ m }})
      end
    {% end %}

    # The current key bindings by name ("up", "page_down", ...).
    def key_map : Hash(String, Key::Binding)
      call("key_map").as_h.transform_values { |b| Key::Binding.from_json(b) }
    end
  end
end
