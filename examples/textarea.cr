# A text editor with line numbers; ctrl+s prints the text and quits, esc
# quits without saving.
#
#   crystal run examples/textarea.cr
require "../src/bubbletea"

class Editor
  include Tea::Model

  getter area = Bubbles::TextArea.new(placeholder: "Once upon a time…", width: 60, height: 10,
    show_line_numbers: true)
  getter? saved = false

  def init
    area.focus
  end

  def update(msg : Tea::Msg)
    case msg
    when Tea::KeyMsg
      case msg.key
      when "esc", "ctrl+c" then return Tea.quit
      when "ctrl+s"
        @saved = true
        return Tea.quit
      end
    when Tea::WindowSizeMsg
      area.width = Math.min(msg.width - 4, 80)
    end
    area.update(msg)
  end

  def view : String
    "\n  Tell me a story.\n\n#{area.view}\n\n  ctrl+s: save • esc: quit (#{area.length} chars, line #{area.line + 1})\n"
  end
end

editor = Tea::Program.new(Editor.new).run
puts editor.area.value if editor.saved?
