require "json"

module Tea
  # Base class of all messages. Define your own messages as subclasses:
  #
  # ```
  # class TickMsg < Tea::Msg
  #   getter time : Time
  #
  #   def initialize(@time); end
  # end
  # ```
  abstract class Msg
    # The JSON form understood by the Go side, if this message can be passed
    # to Bubbles components (keys, mouse, window size, focus, Go messages).
    def to_wire : String?
      nil
    end

    # Decodes one message received from Go.
    def self.from_wire(json : JSON::Any) : Msg?
      case json["type"].as_s
      when "key"         then KeyMsg.from_wire(json)
      when "mouse"       then MouseMsg.from_wire(json)
      when "window_size" then WindowSizeMsg.new(json["width"].as_i, json["height"].as_i)
      when "focus"       then FocusMsg.new
      when "blur"        then BlurMsg.new
      when "go"          then GoMsg.new(json["handle"].as_i64.to_u64, json["go_type"]?.try(&.as_s) || "")
      when "exit"
        ExitMsg.new(json["error"]?.try(&.as_s), json["killed"]?.try(&.as_bool) || false,
          json["interrupted"]?.try(&.as_bool) || false)
      end
    end

    def self.from_wire(json : String) : Msg?
      from_wire(JSON.parse(json))
    end
  end

  # A key press. `#key` is Bubble Tea's string form ("a", "ctrl+c", "enter",
  # "alt+x", "up"), which is what you usually match on:
  #
  # ```
  # case msg
  # when Tea::KeyMsg
  #   case msg.key
  #   when "q", "ctrl+c" then return Tea.quit
  #   when "up", "k"     then @cursor -= 1
  #   end
  # end
  # ```
  class KeyMsg < Msg
    # Bubble Tea's string form ("ctrl+c", "a", "alt+enter").
    getter key : String
    # Name of the key type ("runes", "enter", "ctrl+c", "up", ...).
    getter name : String
    # Bubble Tea's numeric `KeyType`.
    getter key_type : Int32
    # Typed characters (for `runes` and `space`).
    getter runes : String
    getter? alt : Bool
    getter? paste : Bool

    def initialize(@key, @name, @key_type, @runes = "", @alt = false, @paste = false)
    end

    # Builds a key from its string form ("a", "enter", "ctrl+c", "alt+x").
    # Uses the Go key table, so it needs the library.
    def self.new(key : String) : KeyMsg
      json = FFI.call(key) { |p, n| LibTea.bt_key_parse(p, n) }
      parsed = JSON.parse(json)
      raise ArgumentError.new("unknown key: #{key.inspect}") if parsed.raw.nil?
      from_wire(parsed)
    end

    def self.from_wire(json : JSON::Any) : KeyMsg
      new(json["key"]?.try(&.as_s) || "", json["key_name"]?.try(&.as_s) || "",
        json["key_type"]?.try(&.as_i) || 0, json["runes"]?.try(&.as_s) || "",
        json["alt"]?.try(&.as_bool) || false, json["paste"]?.try(&.as_bool) || false)
    end

    # True for plain typed characters.
    def runes? : Bool
      name == "runes"
    end

    # True if `key` is one of `keys`.
    def matches?(*keys : String) : Bool
      keys.includes?(key)
    end

    def to_s(io : IO) : Nil
      io << key
    end

    def to_wire : String?
      {type: "key", key: key, key_type: key_type, key_name: name, runes: runes, alt: alt?, paste: paste?}.to_json
    end
  end

  enum MouseAction
    Press
    Release
    Motion
  end

  enum MouseButton
    None
    Left
    Middle
    Right
    WheelUp
    WheelDown
    WheelLeft
    WheelRight
    Backward
    Forward
    Button10
    Button11
  end

  # A mouse event (needs `mouse: :cell` or `mouse: :all`).
  class MouseMsg < Msg
    getter x : Int32
    getter y : Int32
    getter action : MouseAction
    getter button : MouseButton
    getter? shift : Bool
    getter? alt : Bool
    getter? ctrl : Bool
    # Bubble Tea's string form ("left press", "wheel up", "ctrl+left press").
    getter description : String

    def initialize(@x, @y, @action = MouseAction::Press, @button = MouseButton::Left,
                   @shift = false, @alt = false, @ctrl = false, @description = "")
    end

    def self.from_wire(json : JSON::Any) : MouseMsg
      new(json["x"].as_i, json["y"].as_i, MouseAction.new(json["action"].as_i),
        MouseButton.new(json["button"].as_i), json["shift"]?.try(&.as_bool) || false,
        json["alt"]?.try(&.as_bool) || false, json["ctrl"]?.try(&.as_bool) || false,
        json["key"]?.try(&.as_s) || "")
    end

    def wheel? : Bool
      button.wheel_up? || button.wheel_down? || button.wheel_left? || button.wheel_right?
    end

    def to_s(io : IO) : Nil
      io << description
    end

    def to_wire : String?
      {type: "mouse", x: x, y: y, action: action.value, button: button.value,
       shift: shift?, alt: alt?, ctrl: ctrl?}.to_json
    end
  end

  # Sent at startup and whenever the terminal is resized.
  class WindowSizeMsg < Msg
    getter width : Int32
    getter height : Int32

    def initialize(@width, @height)
    end

    def to_wire : String?
      {type: "window_size", width: width, height: height}.to_json
    end
  end

  # The terminal gained focus (needs `report_focus: true`).
  class FocusMsg < Msg
    def to_wire : String?
      %({"type":"focus"})
    end
  end

  # The terminal lost focus (needs `report_focus: true`).
  class BlurMsg < Msg
    def to_wire : String?
      %({"type":"blur"})
    end
  end

  # A Go message without a Crystal representation, e.g. a spinner tick or a
  # list filter result. Pass it on to your Bubbles components in `update`.
  # It is only valid during the `update` call that received it.
  class GoMsg < Msg
    getter handle : UInt64
    # Go type name, e.g. "spinner.TickMsg".
    getter go_type : String

    def initialize(@handle, @go_type)
    end

    def to_wire : String?
      {type: "go", handle: handle}.to_json
    end

    def release : Nil
      LibTea.bt_msg_free(handle)
    end
  end

  # Internal: the Go program has stopped.
  class ExitMsg < Msg
    getter error : String?
    getter? killed : Bool
    getter? interrupted : Bool

    def initialize(@error, @killed, @interrupted)
    end
  end
end
