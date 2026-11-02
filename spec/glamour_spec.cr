require "./spec_helper"

describe Glamour do
  it "renders markdown" do
    rendered = Glamour.render("# Title\n\nSome *emphasis* and `code`.\n\n- one\n- two\n", style: "notty", width: 40)
    text = strip_ansi(rendered)
    text.should contain "Title"
    text.should contain "emphasis"
    text.should contain "• one"
  end

  it "wraps at the given width" do
    long = "word " * 40
    rendered = strip_ansi(Glamour.render(long, style: "notty", width: 30))
    rendered.lines.map(&.rstrip.size).max.should be <= 30
  end

  it "styles with colours in dark mode" do
    with_color_profile(Lipgloss::ColorProfile::TrueColor) do
      Glamour.render("# Hi", style: "dark").should contain "\e["
    end
  end

  it "renders emoji" do
    Glamour.render(":tada:", style: "notty", emoji: true).should contain "🎉"
  end

  it "raises on unknown styles" do
    expect_raises(Glamour::Error) { Glamour.render("x", style: "no-such-style") }
  end

  it "is reusable" do
    r = Glamour::Renderer.new(style: "ascii", width: 20)
    strip_ansi(r.render("a")).should contain "a"
    strip_ansi(r.render("b")).should contain "b"
  end
end
