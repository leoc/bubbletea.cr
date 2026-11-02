require "json"
require "./tea/lib"

# Markdown rendering for the terminal with Glamour.
#
# ```
# puts Glamour.render("# Hello\n\nThis is *markdown*.", style: "dark", width: 60)
# ```
module Glamour
  class Error < Exception
  end

  # A configured renderer, reusable for many documents.
  class Renderer
    # *style*: "auto" (detect), "dark", "light", "notty", "ascii", "dracula",
    # "pink", "tokyo-night"; or a full Glamour JSON style in *style_json*.
    def initialize(*, @style : String = "auto", @width : Int32? = 80, @emoji = false,
                   @preserve_new_lines = false, @base_url : String? = nil,
                   @style_json : String? = nil, @table_wrap : Bool? = nil,
                   @inline_table_links = false)
    end

    def render(markdown : String) : String
      opts = JSON.build do |j|
        j.object do
          j.field "style", @style
          j.field "word_wrap", @width if @width
          j.field "emoji", @emoji
          j.field "preserve_new_lines", @preserve_new_lines
          j.field "base_url", @base_url if @base_url
          j.field "table_wrap", @table_wrap unless @table_wrap.nil?
          j.field "inline_table_links", @inline_table_links
          if sj = @style_json
            j.field("style_json") { j.raw(sj) }
          end
        end
      end
      res = JSON.parse(Tea::FFI.take!(LibTea.bt_glamour_render(markdown, markdown.bytesize, opts, opts.bytesize)))
      if err = res["error"]?
        raise Error.new(err.as_s)
      end
      res["result"].as_s
    end
  end

  def self.render(markdown : String, **options) : String
    Renderer.new(**options).render(markdown)
  end
end
