# Key bindings with help: arrows move a dot, ? toggles the full help, q quits.
#
#   crystal run examples/help.cr
require "../src/bubbletea"

class Keys
  include Bubbles::Key::KeyMap

  UP    = Bubbles::Key::Binding.new("up", "k", help: {"↑/k", "move up"})
  DOWN  = Bubbles::Key::Binding.new("down", "j", help: {"↓/j", "move down"})
  LEFT  = Bubbles::Key::Binding.new("left", "h", help: {"←/h", "move left"})
  RIGHT = Bubbles::Key::Binding.new("right", "l", help: {"→/l", "move right"})
  HELP  = Bubbles::Key::Binding.new("?", help: {"?", "toggle help"})
  QUIT  = Bubbles::Key::Binding.new("q", "esc", "ctrl+c", help: {"q", "quit"})

  def short_help : Array(Bubbles::Key::Binding)
    [HELP, QUIT]
  end

  def full_help : Array(Array(Bubbles::Key::Binding))
    [[UP, DOWN, LEFT, RIGHT], [HELP, QUIT]]
  end
end

class Mover
  include Tea::Model

  @keys = Keys.new
  @help = Bubbles::Help.new
  @x = 0
  @y = 0
  @last = "nothing yet"

  def update(msg : Tea::Msg)
    case msg
    when Tea::WindowSizeMsg
      @help.width = msg.width
    when Tea::KeyMsg
      case
      when Keys::UP.matches?(msg)    then @y -= 1
      when Keys::DOWN.matches?(msg)  then @y += 1
      when Keys::LEFT.matches?(msg)  then @x -= 1
      when Keys::RIGHT.matches?(msg) then @x += 1
      when Keys::HELP.matches?(msg)  then @help.show_all = !@help.show_all?
      when Keys::QUIT.matches?(msg)  then return Tea.quit
      end
      @last = msg.key
    end
    nil
  end

  def view : String
    "\n  Position: (#{@x}, #{@y})   last key: #{@last}\n\n  #{@help.view(@keys).gsub("\n", "\n  ")}\n"
  end
end

Tea::Program.new(Mover.new).run
