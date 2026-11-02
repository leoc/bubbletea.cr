# A pager for markdown, rendered with Glamour and scrolled with a viewport.
# ↑/↓, pgup/pgdown, mouse wheel; q quits.
#
#   crystal run examples/viewport.cr [FILE.md]   (default: README.md)
require "../src/bubbletea"

class Pager
  include Tea::Model

  TITLE = Lipgloss::Style.new.border(:rounded).padding(0, 1).border_right(false)
  INFO  = Lipgloss::Style.new.border(:rounded).padding(0, 1).border_left(false)
  LINE  = Lipgloss::Style.new.foreground("240")

  @viewport = Bubbles::Viewport.new
  @ready = false

  def initialize(@title : String, @markdown : String)
  end

  def update(msg : Tea::Msg)
    case msg
    when Tea::KeyMsg
      return Tea.quit if msg.matches?("q", "ctrl+c", "esc")
    when Tea::WindowSizeMsg
      chrome = Lipgloss.height(header) + Lipgloss.height(footer)
      @viewport.set_size(msg.width, msg.height - chrome)
      @viewport.content = Glamour.render(@markdown, style: "auto", width: Math.min(msg.width, 100) - 2)
      @ready = true
    end
    @viewport.update(msg)
  end

  private def header : String
    title = TITLE.render(@title)
    line = LINE.render("─" * Math.max(0, (@viewport.width rescue 0) - Lipgloss.width(title)))
    Lipgloss.join_horizontal(:center, title, line)
  end

  private def footer : String
    info = INFO.render("#{(@viewport.scroll_percent * 100).round.to_i}%")
    line = LINE.render("─" * Math.max(0, @viewport.width - Lipgloss.width(info)))
    Lipgloss.join_horizontal(:center, line, info)
  end

  def view : String
    return "\n  Initializing…" unless @ready
    "#{header}\n#{@viewport.view}\n#{footer}"
  end
end

path = ARGV[0]? || File.join(__DIR__, "..", "README.md")
Tea::Program.new(Pager.new(File.basename(path), File.read(path)),
  alt_screen: true, mouse: Tea::MouseMode::CellMotion).run
