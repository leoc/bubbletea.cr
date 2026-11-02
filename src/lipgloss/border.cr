require "json"

module Lipgloss
  # Characters of a custom border. Field names match Lip Gloss.
  struct Border
    include JSON::Serializable

    {% for f in %w(top bottom left right top_left top_right bottom_left bottom_right
                  middle_left middle_right middle middle_top middle_bottom) %}
      @[JSON::Field(key: {{ f.camelcase }})]
      getter {{ f.id }} : String
    {% end %}

    def initialize(@top = "", @bottom = "", @left = "", @right = "",
                   @top_left = "", @top_right = "", @bottom_left = "", @bottom_right = "",
                   @middle_left = "", @middle_right = "", @middle = "",
                   @middle_top = "", @middle_bottom = "")
    end
  end

  # Named borders built into Lip Gloss.
  enum BorderType
    Normal
    Rounded
    Thick
    Double
    Hidden
    Block
    OuterHalfBlock
    InnerHalfBlock
    Markdown
    ASCII

    def wire_name : String
      self.ascii? ? "ascii" : to_s.underscore
    end
  end

  # Border settings of a style or table.
  struct BorderSpec
    getter type : BorderType
    getter chars : Border?
    # top, right, bottom, left; `nil` means all sides.
    getter sides : Array(Bool)?
    getter foreground : Color?
    getter background : Color?

    def initialize(@type = BorderType::Normal, @chars = nil, @sides = nil,
                   @foreground = nil, @background = nil)
    end

    def copy_with(type = @type, chars = @chars, sides = @sides, foreground = @foreground, background = @background)
      BorderSpec.new(type, chars, sides, foreground, background)
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "type", type.wire_name
        json.field "chars", chars if chars
        json.field "sides", sides if sides
        json.field "foreground", foreground unless foreground.nil?
        json.field "background", background unless background.nil?
      end
    end
  end
end
