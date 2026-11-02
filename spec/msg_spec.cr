require "./spec_helper"

describe Tea::Msg do
  it "decodes key messages" do
    msg = Tea::Msg.from_wire(%({"type":"key","key":"ctrl+c","key_type":3,"key_name":"ctrl+c"}))
    msg = msg.as(Tea::KeyMsg)
    msg.key.should eq "ctrl+c"
    msg.name.should eq "ctrl+c"
    msg.key_type.should eq 3
    msg.runes?.should be_false
    msg.to_s.should eq "ctrl+c"
    msg.matches?("q", "ctrl+c").should be_true
  end

  it "decodes typed runes, alt and paste" do
    msg = Tea::Msg.from_wire(%({"type":"key","key":"alt+ä","key_type":-1,"key_name":"runes","runes":"ä","alt":true})).as(Tea::KeyMsg)
    msg.runes?.should be_true
    msg.runes.should eq "ä"
    msg.alt?.should be_true
    msg.paste?.should be_false
  end

  it "decodes mouse messages" do
    msg = Tea::Msg.from_wire(%({"type":"mouse","key":"left press","x":3,"y":7,"action":0,"button":1,"ctrl":true})).as(Tea::MouseMsg)
    msg.x.should eq 3
    msg.y.should eq 7
    msg.action.should eq Tea::MouseAction::Press
    msg.button.should eq Tea::MouseButton::Left
    msg.ctrl?.should be_true
    msg.shift?.should be_false
    msg.wheel?.should be_false
    msg.to_s.should eq "left press"
  end

  it "decodes window size, focus, blur, go and exit messages" do
    ws = Tea::Msg.from_wire(%({"type":"window_size","width":120,"height":40})).as(Tea::WindowSizeMsg)
    {ws.width, ws.height}.should eq({120, 40})
    Tea::Msg.from_wire(%({"type":"focus"})).should be_a(Tea::FocusMsg)
    Tea::Msg.from_wire(%({"type":"blur"})).should be_a(Tea::BlurMsg)
    go = Tea::Msg.from_wire(%({"type":"go","handle":42,"go_type":"spinner.TickMsg"})).as(Tea::GoMsg)
    go.handle.should eq 42
    go.go_type.should eq "spinner.TickMsg"
    exit = Tea::Msg.from_wire(%({"type":"exit","error":"program was interrupted","interrupted":true})).as(Tea::ExitMsg)
    exit.interrupted?.should be_true
    exit.killed?.should be_false
    exit.error.should eq "program was interrupted"
  end

  it "ignores unknown message types" do
    Tea::Msg.from_wire(%({"type":"something_new"})).should be_nil
  end

  describe Tea::KeyMsg do
    it "parses key strings through the Go key table" do
      {"enter", "ctrl+c", "up", "shift+tab", "esc", "f5"}.each do |name|
        key = Tea::KeyMsg.new(name)
        key.key.should eq name
        key.name.should eq name
      end
      a = Tea::KeyMsg.new("a")
      a.runes?.should be_true
      a.runes.should eq "a"
      alt = Tea::KeyMsg.new("alt+x")
      alt.alt?.should be_true
      alt.key.should eq "alt+x"
      Tea::KeyMsg.new(" ").key.should eq " "
    end

    it "round-trips through the wire format" do
      key = Tea::KeyMsg.new("ctrl+d")
      back = Tea::Msg.from_wire(key.to_wire.not_nil!).as(Tea::KeyMsg)
      back.key.should eq "ctrl+d"
      back.key_type.should eq key.key_type
    end

    it "rejects empty keys" do
      expect_raises(ArgumentError) { Tea::KeyMsg.new("") }
    end
  end
end
