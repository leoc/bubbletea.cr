require "./spec_helper"

describe "Lipgloss layout" do
  it "joins horizontally" do
    Lipgloss.join_horizontal(:top, "a\nb", "c").should eq "ac\nb "
    Lipgloss.join_horizontal(:bottom, "a\nb", "c").should eq "a \nbc"
    Lipgloss.join_horizontal(Lipgloss::Top, ["x", "y"]).should eq "xy"
  end

  it "joins vertically" do
    Lipgloss.join_vertical(:left, "abc", "d").should eq "abc\nd  "
    Lipgloss.join_vertical(:right, "abc", "d").should eq "abc\n  d"
    Lipgloss.join_vertical(:center, "abc", "d").should eq "abc\n d "
  end

  it "places text in a box" do
    Lipgloss.place(5, 3, :center, :center, "x").should eq "     \n  x  \n     "
    Lipgloss.place_horizontal(4, :right, "x").should eq "   x"
    Lipgloss.place_vertical(2, :bottom, "x").should eq " \nx"
    Lipgloss.place(3, 1, :left, :top, "x", whitespace_chars: ".").should eq "x.."
  end

  it "measures blocks" do
    Lipgloss.size("abc\nde").should eq({3, 2})
    Lipgloss.width("日本").should eq 4
    Lipgloss.height("a\nb\nc").should eq 3
    with_color_profile(Lipgloss::ColorProfile::TrueColor) do
      Lipgloss.width(Lipgloss::Style.new.foreground("#ff0000").render("abc")).should eq 3
    end
  end
end
