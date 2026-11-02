# An animated progress bar that fills in steps; q quits.
#
#   crystal run examples/progress.cr
require "../src/bubbletea"

class StepMsg < Tea::Msg
end

class Download
  include Tea::Model

  @bar = Bubbles::Progress.new(width: 40, gradient: {"#5A56E0", "#EE6FF8"})
  @value = 0.0

  def init
    step
  end

  private def step
    Tea.tick(0.6.seconds) { StepMsg.new }
  end

  def update(msg : Tea::Msg)
    case msg
    when Tea::KeyMsg
      return Tea.quit if msg.matches?("q", "ctrl+c")
    when Tea::WindowSizeMsg
      @bar.width = Math.min(msg.width - 8, 60)
    when StepMsg
      return Tea.sequence(Tea.tick(0.8.seconds) { nil }, Tea.quit) if @value >= 1.0
      @value = Math.min(1.0, @value + 0.2)
      Tea.batch(@bar.set_percent(@value), step)
    else
      @bar.update(msg) # animation frames
    end
  end

  def view : String
    "\n  #{@bar.view}\n\n  #{Lipgloss::Style.new.foreground("241").render("q: quit")}\n"
  end
end

Tea::Program.new(Download.new).run
