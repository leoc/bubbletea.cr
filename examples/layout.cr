# Lip Gloss layout demo: tabs, boxes, adaptive colours, a table, a clock and
# a simulated background job, centred in the alt screen. tab switches tabs,
# r reloads, q quits.
#
#   crystal run examples/layout.cr
require "../src/bubbletea"

class LoadedMsg < Tea::Msg
  getter rows : Array(Array(String))

  def initialize(@rows)
  end
end

class ClockMsg < Tea::Msg
  getter time : Time

  def initialize(@time)
  end
end

class Layout
  include Tea::Model

  SUBTLE    = Lipgloss::AdaptiveColor.new(light: "#D9DCCF", dark: "#383838")
  HIGHLIGHT = Lipgloss::AdaptiveColor.new(light: "#874BFD", dark: "#7D56F4")
  SPECIAL   = Lipgloss::AdaptiveColor.new(light: "#43BF6D", dark: "#73F59F")

  TAB        = Lipgloss::Style.new.border(:rounded).border_foreground(HIGHLIGHT).padding(0, 1)
  ACTIVE_TAB = TAB.bold.foreground(SPECIAL)
  BOX        = Lipgloss::Style.new.border(:normal).border_foreground(SUBTLE).padding(0, 1).width(28).height(6)
  TITLE      = Lipgloss::Style.new.bold.foreground(HIGHLIGHT).margin_bottom(1)
  STATUS     = Lipgloss::Style.new.foreground("#FFFDF5").background("#5A56E0").padding(0, 1)
  STATUS_BAR = Lipgloss::Style.new.foreground("#C1C6B2").background("#353533")
  HEADER     = Lipgloss::Style.new.bold.foreground(HIGHLIGHT).align(:center)
  CELL       = Lipgloss::Style.new.padding(0, 1)

  TABS = ["Overview", "Data", "About"]

  @tab = 0
  @width = 80
  @height = 24
  @now = Time.local
  @rows : Array(Array(String))? = nil

  def init
    Tea.batch(clock, load, Tea.set_window_title("bubbletea.cr layout"))
  end

  private def clock
    Tea.every(1.second) { |t| ClockMsg.new(t) }
  end

  # A custom async command: runs in its own fiber, the UI stays responsive.
  private def load
    Tea.cmd do
      sleep 1.5.seconds
      LoadedMsg.new([["Bubble Tea", "v1.3.10", "TUI framework"],
                     ["Lip Gloss", "v1.1", "Styles and layout"],
                     ["Bubbles", "v1.0.0", "Components"],
                     ["Glamour", "v1.0.0", "Markdown"]])
    end
  end

  def update(msg : Tea::Msg)
    case msg
    when Tea::WindowSizeMsg
      @width, @height = msg.width, msg.height
    when ClockMsg
      @now = msg.time
      return clock
    when LoadedMsg
      @rows = msg.rows
    when Tea::KeyMsg
      case msg.key
      when "q", "ctrl+c", "esc"     then return Tea.quit
      when "tab", "right", "l"      then @tab = (@tab + 1) % TABS.size
      when "shift+tab", "left", "h" then @tab = (@tab - 1) % TABS.size
      when "r"
        @rows = nil
        return load
      end
    end
    nil
  end

  def view : String
    tabs = Lipgloss.join_horizontal(:bottom, TABS.map_with_index { |t, i| (i == @tab ? ACTIVE_TAB : TAB).render(t) })
    body = case @tab
           when 0 then overview
           when 1 then data
           else        about
           end
    status = status_bar
    content = Lipgloss.join_vertical(:left, tabs, body, "", status)
    Lipgloss.place(@width, @height, :center, :center, content,
      whitespace_chars: "·", whitespace_foreground: SUBTLE)
  end

  private def overview : String
    left = BOX.render(TITLE.render("Styles") + "\nbold, italic, colours,\nborders, padding, margin")
    right = BOX.render(TITLE.render("Layout") + "\njoin horizontal/vertical,\nplace, width, height")
    Lipgloss.join_horizontal(:top, left, " ", right)
  end

  private def data : String
    rows = @rows
    return BOX.width(57).render("Loading…") unless rows
    Lipgloss::Table.new
      .border(:rounded)
      .border_style(Lipgloss::Style.new.foreground(HIGHLIGHT))
      .headers("Library", "Version", "Purpose")
      .rows(rows)
      .width(59)
      .style_func { |row, _| row == Lipgloss::Table::HEADER_ROW ? HEADER : CELL }
      .render
  end

  private def about : String
    BOX.width(57).align(:center).render("bubbletea.cr\n\nCrystal bindings for the Charm stack\nvia a Go c-shared library.")
  end

  private def status_bar : String
    left = STATUS.render("LAYOUT")
    right = STATUS.render(@now.to_s("%H:%M:%S"))
    middle_width = Math.max(0, 59 - Lipgloss.width(left) - Lipgloss.width(right))
    middle = STATUS_BAR.width(middle_width).render(" tab: switch • r: reload • q: quit")
    Lipgloss.join_horizontal(:top, left, middle, right)
  end
end

Tea::Program.new(Layout.new, alt_screen: true).run
