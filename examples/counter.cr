# A counter: up/down or +/- to change, q to quit.
#
#   crystal run examples/counter.cr
require "../src/bubbletea"

class Counter
  include Tea::Model

  STYLE = Lipgloss::Style.new.bold.foreground("#FF5F87").padding(0, 1)
  HELP  = Lipgloss::Style.new.foreground("241")

  getter count = 0

  def update(msg : Tea::Msg)
    case msg
    when Tea::KeyMsg
      case msg.key
      when "q", "ctrl+c", "esc" then return Tea.quit
      when "up", "k", "+"       then @count += 1
      when "down", "j", "-"     then @count -= 1
      end
    end
    nil
  end

  def view : String
    "\n  Count:#{STYLE.render(@count.to_s)}\n\n  #{HELP.render("↑/↓ change • q quit")}\n"
  end
end

model = Tea::Program.new(Counter.new).run
puts "Final count: #{model.count}"
