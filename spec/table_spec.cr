require "./spec_helper"

describe Lipgloss::Table do
  it "renders headers and rows with a border" do
    t = Lipgloss::Table.new.border(:normal).headers("A", "B").row("1", "2").row("3", "4")
    t.render.should eq <<-TXT.chomp
      ┌─┬─┐
      │A│B│
      ├─┼─┤
      │1│2│
      │3│4│
      └─┴─┘
      TXT
  end

  it "toggles border parts" do
    t = Lipgloss::Table.new.border(:ascii).border_column(false).border_header(false)
      .headers("A", "B").rows([["1", "2"]])
    t.render.should eq "+--+\n|AB|\n|12|\n+--+"
  end

  it "applies per-cell styles from a Crystal block" do
    seen = [] of {Int32, Int32}
    header = Lipgloss::Style.new.bold
    cell = Lipgloss::Style.new.padding(0, 1)
    t = Lipgloss::Table.new.headers("A").row("1").row("2")
      .style_func do |row, col|
        seen << {row, col}
        row == Lipgloss::Table::HEADER_ROW ? header : cell
      end
    json = JSON.parse(t.to_json)
    json["styles"].as_a.size.should eq 2 # deduplicated
    json["cell_styles"].should eq [[0], [1], [1]]
    seen.should eq [{-1, 0}, {0, 0}, {1, 0}]
    strip_ansi(t.render).should contain "│ 1 │"
  end

  it "fixes the width" do
    t = Lipgloss::Table.new.border(:normal).headers("A", "B").row("1", "2").width(11)
    t.render.lines.first.size.should eq 11
  end
end
