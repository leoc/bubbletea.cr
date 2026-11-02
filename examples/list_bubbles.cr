# The Bubbles list: filtering with /, paging, status messages, help (?).
# enter picks an item, a adds one, x deletes, q quits.
#
#   crystal run examples/list_bubbles.cr
require "../src/bubbletea"

record Tool, title : String, description : String do
  def filter_value : String
    "#{title} #{description}"
  end
end

class Toolbox
  include Tea::Model

  ADD    = Bubbles::Key::Binding.new("a", help: {"a", "add"})
  DELETE = Bubbles::Key::Binding.new("x", help: {"x", "delete"})
  APP    = Lipgloss::Style.new.padding(1, 2)

  getter list : Bubbles::List(Tool)
  getter picked : Tool? = nil
  @added = 0

  def initialize
    tools = [Tool.new("Bubble Tea", "The Elm Architecture for TUIs"),
             Tool.new("Lip Gloss", "Style definitions for nice layouts"),
             Tool.new("Bubbles", "TUI components"), Tool.new("Glamour", "Markdown rendering"),
             Tool.new("Harmonica", "Spring animations"), Tool.new("Wish", "SSH apps"),
             Tool.new("Gum", "Glamorous shell scripts"), Tool.new("VHS", "Terminal GIFs"),
             Tool.new("Soft Serve", "Git server"), Tool.new("Glow", "Markdown reader"),
             Tool.new("Mods", "AI on the command line"), Tool.new("Skate", "Key-value store")]
    @list = Bubbles::List(Tool).new(tools, title: "Charm tools",
      styles: {"title" => Lipgloss::Style.new.background("#25A065").foreground("#FFFDF5").padding(0, 1)},
      additional_short_help: [ADD, DELETE], additional_full_help: [[ADD, DELETE]])
  end

  def update(msg : Tea::Msg)
    case msg
    when Tea::WindowSizeMsg
      list.set_size(msg.width - APP.horizontal_frame_size, msg.height - APP.vertical_frame_size)
    when Tea::KeyMsg
      unless list.setting_filter? # let the filter input get all keys
        case
        when msg.key == "enter"
          @picked = list.selected_item
          return Tea.quit
        when ADD.matches?(msg)
          @added += 1
          tool = Tool.new("New tool #{@added}", "added at #{Time.local.to_s("%H:%M:%S")}")
          return Tea.batch(list.insert_item(0, tool), list.new_status_message("Added #{tool.title}"))
        when DELETE.matches?(msg)
          if removed = list.remove_item(list.global_index)
            return list.new_status_message("Deleted #{removed.title}")
          end
        end
      end
    end
    list.update(msg)
  end

  def view : String
    APP.render(list.view)
  end
end

model = Tea::Program.new(Toolbox.new, alt_screen: true).run
puts "Picked: #{model.picked.try(&.title) || "nothing"}"
