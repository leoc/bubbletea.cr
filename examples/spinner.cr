# Spinner while a background job runs; any key quits.
#
#   crystal run examples/spinner.cr
require "../src/bubbletea"

class DoneMsg < Tea::Msg
end

class Loading
  include Tea::Model

  @spinner = Bubbles::Spinner.new(Bubbles::Spinner::Type::Dot, style: Lipgloss::Style.new.foreground("205"))
  @done = false

  def init
    work = Tea.cmd do
      sleep 3.seconds
      DoneMsg.new
    end
    Tea.batch(@spinner.tick, work)
  end

  def update(msg : Tea::Msg)
    case msg
    when Tea::KeyMsg then Tea.quit
    when DoneMsg
      @done = true
      Tea.quit
    else
      @spinner.update(msg) # spinner ticks arrive as Tea::GoMsg
    end
  end

  def view : String
    @done ? "Done!\n" : "\n #{@spinner.view} Loading forever… (well, 3 seconds; any key quits)\n\n"
  end
end

Tea::Program.new(Loading.new).run
