require "./spec_helper"

private class PingMsg < Tea::Msg
end

describe "Tea commands" do
  it "drops nil entries in batch and sequence" do
    Tea.batch(nil, nil).should be_nil
    Tea.sequence(nil).should be_nil
    one = Tea.quit
    Tea.batch(nil, one).should be(one)
    Tea.batch(one, Tea.clear_screen).should be_a(Tea::BatchCmd)
    Tea.sequence(one, nil).as(Tea::SequenceCmd).cmds.should eq [one]
  end

  it "builds control commands" do
    Tea.quit.as(Tea::ControlCmd).type.should eq "quit"
    Tea.enter_alt_screen.as(Tea::ControlCmd).type.should eq "enter_alt_screen"
    title = Tea.set_window_title("hi").as(Tea::ControlCmd)
    {title.type, title.text}.should eq({"set_window_title", "hi"})
  end

  it "wraps blocks as async and tick commands" do
    Tea.cmd { PingMsg.new }.as(Tea::AsyncCmd).proc.call.should be_a(PingMsg)
    tick = Tea.tick(1.second) { |_| PingMsg.new }.as(Tea::TickCmd)
    tick.span.should eq 1.second
    tick.align?.should be_false
    Tea.every(1.second) { nil }.as(Tea::TickCmd).align?.should be_true
  end
end
