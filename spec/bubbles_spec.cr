require "./spec_helper"

private def key(k : String) : Tea::KeyMsg
  Tea::KeyMsg.new(k)
end

private def type_into(c : Bubbles::Component, text : String)
  text.each_char { |ch| c.update(key(ch.to_s)) }
end

private record Fruit, title : String, description : String = "", price : Int32 = 0

describe Bubbles::TextInput do
  it "edits text through key messages" do
    input = Bubbles::TextInput.new(placeholder: "name", prompt: "> ")
    input.focus.should be_a(Tea::GoCmd) # cursor blink
    input.focused?.should be_true
    type_into(input, "hello")
    input.value.should eq "hello"
    input.update(key("backspace"))
    input.value.should eq "hell"
    input.update(key("ctrl+a"))
    input.position.should eq 0
    input.update(key("ctrl+e"))
    input.position.should eq 4
  end

  it "ignores keys while blurred" do
    input = Bubbles::TextInput.new
    type_into(input, "x")
    input.value.should eq ""
  end

  it "renders prompt, placeholder and masked input" do
    input = Bubbles::TextInput.new(placeholder: "name", prompt: "> ")
    strip_ansi(input.view).should start_with "> n"
    pw = Bubbles::TextInput.new(echo_mode: Bubbles::TextInput::EchoMode::Password, value: "secret")
    strip_ansi(pw.view).should contain "******"
  end

  it "limits characters and sets values" do
    input = Bubbles::TextInput.new(char_limit: 3)
    input.focus
    type_into(input, "abcdef")
    input.value.should eq "abc"
    input.value = "xy"
    input.value.should eq "xy"
    input.reset
    input.value.should eq ""
  end

  it "completes suggestions" do
    input = Bubbles::TextInput.new(suggestions: ["crystal", "go"], show_suggestions: true)
    input.focus
    type_into(input, "cr")
    input.current_suggestion.should eq "crystal"
    input.update(key("tab"))
    input.value.should eq "crystal"
  end

  it "accepts custom key bindings" do
    input = Bubbles::TextInput.new(key_map: {"delete_character_backward" => Bubbles::Key::Binding.new("ctrl+h")})
    input.focus
    type_into(input, "ab")
    input.update(key("backspace"))
    input.value.should eq "ab"
    input.update(key("ctrl+h"))
    input.value.should eq "a"
    input.key_map["delete_character_backward"].keys.should eq ["ctrl+h"]
  end

  it "raises on bad options" do
    expect_raises(Bubbles::Error, /unknown key binding/) do
      Bubbles::TextInput.new(key_map: {"nope" => Bubbles::Key::Binding.new("x")})
    end
  end
end

describe Bubbles::TextArea do
  it "edits multiple lines" do
    area = Bubbles::TextArea.new(width: 30, height: 5)
    area.focus
    type_into(area, "one")
    area.update(key("enter"))
    type_into(area, "two")
    area.value.should eq "one\ntwo"
    area.line_count.should eq 2
    area.line.should eq 1
    area.insert_string("!")
    area.value.should eq "one\ntwo!"
    strip_ansi(area.view).should contain "two!"
  end
end

describe Bubbles::Viewport do
  it "scrolls content" do
    content = (1..20).map { |i| "line #{i}" }.join("\n")
    vp = Bubbles::Viewport.new(20, 5, content: content)
    vp.at_top?.should be_true
    vp.total_line_count.should eq 20
    vp.view.lines.first.should start_with "line 1"
    vp.update(key("down"))
    vp.y_offset.should eq 1
    vp.page_down
    vp.y_offset.should eq 6
    vp.goto_bottom
    vp.at_bottom?.should be_true
    vp.scroll_percent.should eq 1.0
    vp.update(Tea::MouseMsg.new(0, 0, Tea::MouseAction::Press, Tea::MouseButton::WheelUp))
    vp.y_offset.should eq 12
    vp.key_map.keys.should contain "page_down"
  end
end

describe Bubbles::Spinner do
  it "advances on its own tick messages" do
    spinner = Bubbles::Spinner.new(frames: ["a", "b", "c"], fps: 100.0)
    spinner.view.should eq "a"
    spinner.tick.should be_a(Tea::GoCmd)
    spinner.id.should be > 0
  end

  it "supports the built-in spinner types" do
    Bubbles::Spinner::Type.each do |type|
      next if type.ellipsis? # its first frame is ""
      Bubbles::Spinner.new(type).view.should_not be_empty
    end
  end
end

describe Bubbles::Progress do
  it "renders static percentages" do
    bar = Bubbles::Progress.new(width: 20, solid_fill: "#00ff00", full: '#', empty: '.', show_percentage: false)
    strip_ansi(bar.view_as(0.5)).should eq "##########.........."
    bar.set_percent(0.25).should be_a(Tea::GoCmd)
    bar.percent.should eq 0.25
  end

  it "shows the percentage" do
    bar = Bubbles::Progress.new(width: 20)
    strip_ansi(bar.view_as(1.0)).should end_with "100%"
  end
end

describe Bubbles::Paginator do
  it "pages through items" do
    p = Bubbles::Paginator.new(per_page: 3)
    p.set_total_pages(10).should eq 4
    p.slice_bounds(10).should eq 0...3
    p.update(key("right"))
    p.page.should eq 1
    p.slice_bounds(10).should eq 3...6
    p.view.should eq "2/4"
    p.page = 3
    p.on_last_page?.should be_true
    p.items_on_page(10).should eq 1
  end

  it "renders dots" do
    p = Bubbles::Paginator.new(type: Bubbles::Paginator::Type::Dots, total_pages: 3, active_dot: "o", inactive_dot: ".")
    p.view.should eq "o.."
  end
end

private class AppKeys
  include Bubbles::Key::KeyMap

  UP   = Bubbles::Key::Binding.new("up", "k", help: {"↑/k", "up"})
  QUIT = Bubbles::Key::Binding.new("q", help: {"q", "quit"})

  def short_help : Array(Bubbles::Key::Binding)
    [UP, QUIT]
  end

  def full_help : Array(Array(Bubbles::Key::Binding))
    [[UP], [QUIT]]
  end
end

describe Bubbles::Key do
  it "matches key messages" do
    AppKeys::UP.matches?(key("k")).should be_true
    AppKeys::UP.matches?(key("j")).should be_false
    Bubbles::Key.matches?(key("q"), AppKeys::UP, AppKeys::QUIT).should be_true
    disabled = Bubbles::Key::Binding.new("x", enabled: false)
    disabled.matches?(key("x")).should be_false
  end
end

describe Bubbles::Help do
  it "renders short and full help" do
    help = Bubbles::Help.new
    help.view(AppKeys.new).should eq "↑/k up • q quit"
    help.show_all = true
    full = help.view(AppKeys.new)
    full.should contain "↑/k up"
    full.lines.size.should eq 1 # two columns side by side
  end

  it "truncates to the width" do
    Bubbles::Help.new(width: 10).view(AppKeys.new).should end_with "…"
  end
end

describe Bubbles::Table do
  it "navigates rows" do
    t = Bubbles::Table.new(
      [Bubbles::Table::Column.new("Name", 10), Bubbles::Table::Column.new("Age", 5)],
      [["Ann", "31"], ["Bob", "42"], ["Cid", "27"]],
      height: 5, focused: true)
    t.selected_row.should eq ["Ann", "31"]
    t.update(key("down"))
    t.cursor.should eq 1
    t.selected_row.should eq ["Bob", "42"]
    t.goto_bottom
    t.selected_row.should eq ["Cid", "27"]
    strip_ansi(t.view).should contain "Name"
    t.short_help.map(&.help_desc).should contain "up"
    t.rows.size.should eq 3
  end
end

describe Bubbles::List do
  it "keeps Crystal items and reports the selection" do
    fruits = [Fruit.new("Apple", "red", 3), Fruit.new("Banana", "yellow", 2), Fruit.new("Cherry", "dark", 5)]
    list = Bubbles::List(Fruit).new(fruits, title: "Fruit", width: 40, height: 20)
    list.items.should eq fruits
    list.selected_item.should eq fruits[0]
    list.update(key("down"))
    list.selected_item.not_nil!.price.should eq 2
    list.index.should eq 1
    strip_ansi(list.view).should contain "Banana"
  end

  it "filters" do
    list = Bubbles::List(String).new(["alpha", "beta", "gamma"], width: 40, height: 20)
    list.set_filter_text("ga")
    list.visible_items.should eq ["gamma"]
    list.filter_state.should eq Bubbles::List::FilterState::FilterApplied
    list.reset_filter
    list.visible_items.size.should eq 3
  end

  it "filters interactively through Go messages" do
    list = Bubbles::List(String).new(["alpha", "beta", "gamma"], width: 40, height: 20)
    list.update(key("/"))
    list.setting_filter?.should be_true
    # typing returns a Go command that computes the matches asynchronously
    list.update(key("b")).should be_a(Tea::GoCmd)
  end

  it "inserts, replaces and removes items" do
    list = Bubbles::List(Bubbles::ListItem).new([Bubbles::ListItem.new("a")], width: 40, height: 20)
    list.insert_item(1, Bubbles::ListItem.new("b"))
    list.set_item(0, Bubbles::ListItem.new("z", "zed"))
    list.items.map(&.title).should eq ["z", "b"]
    list.remove_item(0).not_nil!.title.should eq "z"
    list.items.map(&.title).should eq ["b"]
    list.set_items([Bubbles::ListItem.new("n")])
    list.items.map(&.title).should eq ["n"]
  end

  it "exposes help bindings" do
    list = Bubbles::List(String).new(["a"], width: 40, height: 20)
    list.short_help.map(&.help_desc).should contain "filter"
    Bubbles::Help.new.view(list).should contain "filter"
  end
end

describe "component handles" do
  it "frees Go components when collected" do
    before = Tea::FFI.handle_counts["components"]
    100.times { Bubbles::Paginator.new }
    GC.collect
    GC.collect
    Tea::FFI.handle_counts["components"].should be < before + 100
  end
end
