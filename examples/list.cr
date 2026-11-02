# A shopping list: move with ↑/↓ (or j/k, mouse wheel), toggle with
# space/enter or a click, q to quit.
#
#   crystal run examples/list.cr
require "../src/bubbletea"

class ShoppingList
  include Tea::Model

  CURSOR   = Lipgloss::Style.new.foreground("#FF5F87").bold
  SELECTED = Lipgloss::Style.new.foreground("#04B575")
  TITLE    = Lipgloss::Style.new.bold.background("#7D56F4").foreground("#FAFAFA").padding(0, 1)
  HELP     = Lipgloss::Style.new.foreground("241")
  HEADER   = 2 # lines above the first item

  getter choices = ["Buy carrots", "Buy celery", "Buy kohlrabi", "Buy cucumbers", "Buy tea"]
  getter selected = Set(Int32).new
  @cursor = 0
  @width = 0

  def update(msg : Tea::Msg)
    case msg
    when Tea::WindowSizeMsg
      @width = msg.width
    when Tea::KeyMsg
      case msg.key
      when "q", "ctrl+c" then return Tea.quit
      when "up", "k"     then move(-1)
      when "down", "j"   then move(1)
      when " ", "enter"  then toggle(@cursor)
      when "home", "g"   then @cursor = 0
      when "end", "G"    then @cursor = choices.size - 1
      end
    when Tea::MouseMsg
      if msg.button.wheel_up?
        move(-1)
      elsif msg.button.wheel_down?
        move(1)
      elsif msg.button.left? && msg.action.press?
        index = msg.y - HEADER
        if 0 <= index < choices.size
          @cursor = index
          toggle(index)
        end
      end
    end
    nil
  end

  private def move(delta)
    @cursor = (@cursor + delta).clamp(0, choices.size - 1)
  end

  private def toggle(i)
    selected.includes?(i) ? selected.delete(i) : selected.add(i)
  end

  def view : String
    String.build do |s|
      s << TITLE.render("What should we buy?") << "\n\n"
      choices.each_with_index do |choice, i|
        cursor = i == @cursor ? CURSOR.render(">") : " "
        check = selected.includes?(i) ? SELECTED.render("[x]") : "[ ]"
        label = selected.includes?(i) ? SELECTED.render(choice) : choice
        s << cursor << " " << check << " " << label << "\n"
      end
      s << "\n" << HELP.render("↑/↓ move • space toggle • click toggles • q quit") << "\n"
    end
  end
end

model = Tea::Program.new(ShoppingList.new, mouse: Tea::MouseMode::CellMotion).run
bought = model.selected.map { |i| model.choices[i] }
puts bought.empty? ? "Nothing selected." : "Selected: #{bought.join(", ")}"
