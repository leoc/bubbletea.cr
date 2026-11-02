# An interactive table of programming languages; enter prints the selected
# row, q quits.
#
#   crystal run examples/table.cr
require "../src/bubbletea"

class Languages
  include Tea::Model

  BASE = Lipgloss::Style.new.border(:normal).border_foreground("240")

  getter table : Bubbles::Table
  getter chosen : Array(String)? = nil

  def initialize
    columns = [Bubbles::Table::Column.new("Language", 12), Bubbles::Table::Column.new("Year", 6),
               Bubbles::Table::Column.new("Paradigm", 24)]
    rows = [["Crystal", "2014", "OOP, compiled"], ["Go", "2009", "imperative, concurrent"],
            ["Ruby", "1995", "OOP, dynamic"], ["Elm", "2012", "functional"],
            ["OCaml", "1996", "functional, OOP"], ["Rust", "2015", "multi-paradigm"],
            ["Haskell", "1990", "pure functional"], ["Erlang", "1986", "concurrent, functional"]]
    @table = Bubbles::Table.new(columns, rows, height: 6, focused: true,
      header_style: Lipgloss::Style.new.bold.border(:normal).border_foreground("240").border_top(false)
        .border_left(false).border_right(false).padding(0, 1),
      selected_style: Lipgloss::Style.new.foreground("229").background("57"))
  end

  def update(msg : Tea::Msg)
    if msg.is_a?(Tea::KeyMsg)
      case msg.key
      when "q", "ctrl+c" then return Tea.quit
      when "esc"         then table.focused? ? table.blur : table.focus
      when "enter"
        @chosen = table.selected_row
        return Tea.quit
      end
    end
    table.update(msg)
  end

  def view : String
    BASE.render(table.view) + "\n  " + table.help_view + "\n"
  end
end

model = Tea::Program.new(Languages.new).run
if row = model.chosen
  puts "You chose #{row[0]} (#{row[1]})."
end
