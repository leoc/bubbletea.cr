require "./spec_helper"

describe Lipgloss::Style do
  it "is immutable: setters return copies" do
    base = Lipgloss::Style.new
    bold = base.bold
    base.to_json.should eq "{}"
    bold.to_json.should eq %({"bold":true})
  end

  it "serialises text attributes, colours and sizes" do
    s = Lipgloss::Style.new.bold.italic(false).foreground("#FF00FF").background("21").width(10).max_height(3)
    json = JSON.parse(s.to_json)
    json["bold"].as_bool.should be_true
    json["italic"].as_bool.should be_false
    json["foreground"].as_s.should eq "#FF00FF"
    json["background"].as_s.should eq "21"
    json["width"].as_i.should eq 10
    json["max_height"].as_i.should eq 3
  end

  it "serialises adaptive and complete colours" do
    s = Lipgloss::Style.new
      .foreground(Lipgloss::AdaptiveColor.new(light: "#000000", dark: "#ffffff"))
      .background(Lipgloss::CompleteColor.new(true_color: "#0000ff", ansi256: "21", ansi: "4"))
    json = JSON.parse(s.to_json)
    json["foreground"].as_h.should eq({"light" => JSON::Any.new("#000000"), "dark" => JSON::Any.new("#ffffff")})
    json["background"]["ansi256"].as_s.should eq "21"
  end

  it "expands padding and margin shorthand like CSS" do
    JSON.parse(Lipgloss::Style.new.padding(1).to_json)["padding"].should eq [1, 1, 1, 1]
    JSON.parse(Lipgloss::Style.new.padding(1, 2).to_json)["padding"].should eq [1, 2, 1, 2]
    JSON.parse(Lipgloss::Style.new.margin(1, 2, 3).to_json)["margin"].should eq [1, 2, 3, 2]
    JSON.parse(Lipgloss::Style.new.padding(1, 2).padding_left(5).to_json)["padding"].should eq [1, 2, 1, 5]
    expect_raises(ArgumentError) { Lipgloss::Style.new.padding(1, 2, 3, 4, 5) }
  end

  it "serialises borders with sides and colours" do
    s = Lipgloss::Style.new.border(:rounded).border_left(false).border_foreground("63")
    border = JSON.parse(s.to_json)["border"]
    border["type"].as_s.should eq "rounded"
    border["sides"].should eq [true, true, true, false]
    border["foreground"].as_s.should eq "63"
    JSON.parse(Lipgloss::Style.new.border(:double, true, false).to_json)["border"]["sides"].should eq [true, false, true, false]
    JSON.parse(Lipgloss::Style.new.border(:outer_half_block).to_json)["border"]["type"].as_s.should eq "outer_half_block"
    JSON.parse(Lipgloss::Style.new.border(Lipgloss::BorderType::ASCII).to_json)["border"]["type"].as_s.should eq "ascii"
  end

  it "maps positions" do
    JSON.parse(Lipgloss::Style.new.align(:center, :bottom).to_json)["align"].as_f.should eq 0.5
    JSON.parse(Lipgloss::Style.new.align(:center, :bottom).to_json)["align_vertical"].as_f.should eq 1.0
    JSON.parse(Lipgloss::Style.new.align(0.25).to_json)["align"].as_f.should eq 0.25
    expect_raises(ArgumentError) { Lipgloss::Style.new.align(:nowhere) }
  end

  it "unsets properties" do
    Lipgloss::Style.new.bold.unset_bold.to_json.should eq "{}"
    Lipgloss::Style.new.padding(2).unset_padding.to_json.should eq "{}"
    Lipgloss::Style.new.border.unset_border.to_json.should eq "{}"
  end

  it "inherits unset properties" do
    base = Lipgloss::Style.new.bold.foreground("1")
    s = Lipgloss::Style.new.foreground("2").inherit(base)
    json = JSON.parse(s.to_json)
    json["bold"].as_bool.should be_true
    json["foreground"].as_s.should eq "2"
  end

  it "compares by value" do
    Lipgloss::Style.new.bold.should eq Lipgloss::Style.new.bold
    Lipgloss::Style.new.bold.should_not eq Lipgloss::Style.new.italic
  end

  describe "#render" do
    it "renders plain text in the ascii profile" do
      Lipgloss::Style.new.bold.foreground("#ff0000").render("hi").should eq "hi"
    end

    it "pads, sizes and aligns" do
      Lipgloss::Style.new.padding(0, 2).render("x").should eq "  x  "
      Lipgloss::Style.new.width(6).align(:right).render("ab").should eq "    ab"
      Lipgloss::Style.new.width(6).align(:center).render("ab").should eq "  ab  "
      Lipgloss::Style.new.height(3).render("a").lines.size.should eq 3
    end

    it "draws borders" do
      Lipgloss::Style.new.border(:rounded).render("hi").should eq "╭──╮\n│hi│\n╰──╯"
      Lipgloss::Style.new.border(:normal, true, false).render("hi").should eq "──\nhi\n──"
      custom = Lipgloss::Border.new(top: "=", bottom: "=", left: "|", right: "|",
        top_left: "+", top_right: "+", bottom_left: "+", bottom_right: "+")
      Lipgloss::Style.new.border(custom).render("x").should eq "+=+\n|x|\n+=+"
    end

    it "joins several strings with spaces" do
      Lipgloss::Style.new.render("a", "b").should eq "a b"
    end

    it "emits true colour sequences when the profile allows it" do
      with_color_profile(Lipgloss::ColorProfile::TrueColor) do
        rendered = Lipgloss::Style.new.bold.foreground("#ff0000").render("hi")
        rendered.should contain "38;2;255;0;0"
        strip_ansi(rendered).should eq "hi"
      end
    end

    it "degrades colours to ANSI 256" do
      with_color_profile(Lipgloss::ColorProfile::ANSI256) do
        Lipgloss::Style.new.foreground("#ff0000").render("hi").should contain "38;5;196"
      end
    end

    it "picks adaptive colours by background" do
      with_color_profile(Lipgloss::ColorProfile::ANSI256) do
        s = Lipgloss::Style.new.foreground(Lipgloss::AdaptiveColor.new(light: "1", dark: "2"))
        Lipgloss.dark_background = false
        s.render("x").should contain "\e[31m"
        Lipgloss.dark_background = true
        s.render("x").should contain "\e[32m"
      end
    end

    it "transforms and renders a stored string" do
      Lipgloss::Style.new.transform(:upper).render("abc").should eq "ABC"
      Lipgloss::Style.new.set_string("hello").to_s.should eq "hello"
    end
  end

  it "reports frame sizes" do
    s = Lipgloss::Style.new.padding(1, 2).margin(0, 1).border(:normal)
    s.horizontal_frame_size.should eq 2 + 4 + 2
    s.vertical_frame_size.should eq 2 + 2
  end
end
