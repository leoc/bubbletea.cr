module Bubbles
  # A single-line text input (`bubbles/textinput`).
  #
  # ```
  # input = Bubbles::TextInput.new(placeholder: "Name", char_limit: 64, width: 20)
  # cmd = input.focus # start the cursor blink: return it from init
  # ```
  class TextInput < Component
    enum EchoMode
      Normal
      Password
      None
    end

    def initialize(*, placeholder : String? = nil, prompt : String? = nil, value : String? = nil,
                   char_limit : Int32? = nil, width : Int32? = nil, echo_mode : EchoMode? = nil,
                   echo_character : Char? = nil, suggestions : Array(String)? = nil,
                   show_suggestions : Bool? = nil, prompt_style : Lipgloss::Style? = nil,
                   text_style : Lipgloss::Style? = nil, placeholder_style : Lipgloss::Style? = nil,
                   completion_style : Lipgloss::Style? = nil, cursor_style : Lipgloss::Style? = nil,
                   key_map : Hash(String, Key::Binding)? = nil)
      super("textinput", {placeholder: placeholder, prompt: prompt, value: value,
                          char_limit: char_limit, width: width,
                          echo_mode: echo_mode.try(&.to_s.downcase),
                          echo_character: echo_character.try(&.to_s), suggestions: suggestions,
                          show_suggestions: show_suggestions, prompt_style: prompt_style,
                          text_style: text_style, placeholder_style: placeholder_style,
                          completion_style: completion_style, cursor_style: cursor_style,
                          key_map: key_map})
    end

    def value : String
      call("value").as_s
    end

    def value=(value : String) : String
      call("set_value", value)
      value
    end

    # Focuses the input; returns the cursor blink command.
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

    # Cursor position (in characters).
    def position : Int32
      call("position").as_i
    end

    def cursor=(position : Int32) : Int32
      call("set_cursor", position)
      position
    end

    def cursor_start : Nil
      call("cursor_start")
    end

    def cursor_end : Nil
      call("cursor_end")
    end

    def suggestions=(list : Array(String)) : Array(String)
      configure(suggestions: list)
      list
    end

    def current_suggestion : String
      call("current_suggestion").as_s
    end

    def matched_suggestions : Array(String)
      call("matched_suggestions").as_a?.try(&.map(&.as_s)) || [] of String
    end

    def key_map : Hash(String, Key::Binding)
      call("key_map").as_h.transform_values { |b| Key::Binding.from_json(b) }
    end
  end
end
