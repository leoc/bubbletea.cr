require "json"

module Lipgloss
  private def self.layout(**spec) : String
    json = spec.to_json
    Tea::FFI.take!(LibTea.bt_lipgloss_layout(json, json.bytesize))
  end

  # Joins blocks side by side, aligned along the vertical axis at *pos*.
  def self.join_horizontal(pos : Position, *blocks : String) : String
    join_horizontal(pos, blocks.to_a)
  end

  def self.join_horizontal(pos : Position, blocks : Array(String)) : String
    layout(op: "join_horizontal", pos: position(pos), strs: blocks)
  end

  # Stacks blocks, aligned along the horizontal axis at *pos*.
  def self.join_vertical(pos : Position, *blocks : String) : String
    join_vertical(pos, blocks.to_a)
  end

  def self.join_vertical(pos : Position, blocks : Array(String)) : String
    layout(op: "join_vertical", pos: position(pos), strs: blocks)
  end

  # Places *str* in a *width* × *height* box.
  def self.place(width : Int, height : Int, h_pos : Position, v_pos : Position, str : String, *,
                 whitespace_chars : String = "", whitespace_foreground : Color? = nil,
                 whitespace_background : Color? = nil) : String
    layout(op: "place", width: width, height: height, pos: position(h_pos), vpos: position(v_pos),
      str: str, whitespace_chars: whitespace_chars, whitespace_foreground: whitespace_foreground,
      whitespace_background: whitespace_background)
  end

  def self.place_horizontal(width : Int, pos : Position, str : String, *,
                            whitespace_chars : String = "", whitespace_foreground : Color? = nil,
                            whitespace_background : Color? = nil) : String
    layout(op: "place_horizontal", width: width, pos: position(pos), str: str,
      whitespace_chars: whitespace_chars, whitespace_foreground: whitespace_foreground,
      whitespace_background: whitespace_background)
  end

  def self.place_vertical(height : Int, pos : Position, str : String, *,
                          whitespace_chars : String = "", whitespace_foreground : Color? = nil,
                          whitespace_background : Color? = nil) : String
    layout(op: "place_vertical", height: height, pos: position(pos), str: str,
      whitespace_chars: whitespace_chars, whitespace_foreground: whitespace_foreground,
      whitespace_background: whitespace_background)
  end

  # Cell width and line count of a rendered block (ANSI-aware).
  def self.size(str : String) : {Int32, Int32}
    h = Hash(String, Int32).from_json(Tea::FFI.take!(LibTea.bt_lipgloss_size(str, str.bytesize)))
    {h["width"], h["height"]}
  end

  def self.width(str : String) : Int32
    size(str)[0]
  end

  def self.height(str : String) : Int32
    size(str)[1]
  end
end
