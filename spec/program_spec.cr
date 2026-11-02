require "./spec_helper"

private class Ping < Tea::Msg
  getter name : String

  def initialize(@name)
  end
end

# Records every message and quits on "q".
private class Recorder
  include Tea::Model

  getter log = [] of String
  getter keys = [] of String
  property init_cmd : Tea::Cmd? = nil
  property on_key : Proc(Tea::KeyMsg, Tea::Cmd?)? = nil

  def init
    @init_cmd
  end

  def update(msg : Tea::Msg)
    case msg
    when Ping
      @log << msg.name
      Tea.quit if msg.name == "stop"
    when Tea::KeyMsg
      @keys << msg.key
      return Tea.quit if msg.key == "q"
      @on_key.try(&.call(msg))
    end
  end

  def view : String
    "keys: #{@keys.join(",")}\n"
  end
end

# Runs a model headless: input from a pipe, output into a file.
private def run_headless(model, input : String? = nil, &)
  reader, writer = IO.pipe
  File.tempfile("tea-out") do |output_file|
    program = Tea::Program.new(model, input_io: reader, output_io: output_file, signals: false)
    if input
      spawn do
        sleep 50.milliseconds
        writer << input
        writer.flush
      end
    end
    done = Channel(Nil).new
    spawn do
      sleep 5.seconds
      program.kill unless done.closed?
    end
    program.run
    done.close
    yield program, File.read(output_file.path)
  end
ensure
  reader.try &.close
  writer.try &.close
end

describe Tea::Program do
  it "delivers keys from the input and renders views" do
    model = Recorder.new
    run_headless(model, "ab\rq") do |program, output|
      program.killed?.should be_false
      # Bubble Tea groups runes that arrive in one read into one key message
      model.keys.should eq ["ab", "enter", "q"]
      output.should contain "keys: ab,enter"
    end
  end

  it "decodes escape sequences into named keys" do
    model = Recorder.new
    run_headless(model, "\e[A\e[B\x03q") do
      model.keys.should eq ["up", "down", "ctrl+c", "q"]
    end
  end

  it "runs sequences in order and batches concurrently" do
    model = Recorder.new
    model.init_cmd = Tea.sequence(
      Tea.tick(30.milliseconds) { Ping.new("tick") },
      Tea.batch(
        Tea.cmd { sleep 20.milliseconds; Ping.new("slow") },
        Tea.cmd { Ping.new("fast") },
      ),
      Tea.msg(Ping.new("after-batch")),
      Tea.cmd { Ping.new("stop") },
    )
    run_headless(model) do
      model.log.should eq ["tick", "fast", "slow", "after-batch", "stop"]
    end
  end

  it "executes commands returned from update" do
    model = Recorder.new
    model.on_key = ->(key : Tea::KeyMsg) : Tea::Cmd? do
      key.key == "x" ? Tea.sequence(Tea.cmd { Ping.new("from-x") }, Tea.cmd { Ping.new("stop") }) : nil
    end
    run_headless(model, "x") { }
    model.log.should eq ["from-x", "stop"]
  end

  it "accepts messages sent from other fibers" do
    model = Recorder.new
    reader, writer = IO.pipe
    File.tempfile("tea-out") do |output_file|
      program = Tea::Program.new(model, input_io: reader, output_io: output_file, signals: false)
      spawn do
        sleep 30.milliseconds
        program.send(Ping.new("external"))
        program.quit
      end
      program.run
    end
    reader.close
    writer.close
    model.log.should eq ["external"]
  end

  it "restores and re-raises when update raises" do
    model = Recorder.new
    model.on_key = ->(key : Tea::KeyMsg) : Tea::Cmd? { raise "boom" }
    expect_raises(Exception, "boom") do
      run_headless(model, "z") { }
    end
    Tea::FFI.handle_counts["programs"].should eq 0
  end

  it "re-raises exceptions from command fibers" do
    model = Recorder.new
    model.init_cmd = Tea.cmd { raise "cmd failed" }
    expect_raises(Exception, "cmd failed") do
      run_headless(model) { }
    end
  end

  it "reports a killed program" do
    model = Recorder.new
    reader, writer = IO.pipe
    File.tempfile("tea-out") do |output_file|
      program = Tea::Program.new(model, input_io: reader, output_io: output_file, signals: false)
      spawn do
        sleep 30.milliseconds
        program.kill
      end
      program.run
      program.killed?.should be_true
    end
    reader.close
    writer.close
  end

  it "frees all handles after running" do
    counts = Tea::FFI.handle_counts
    counts["programs"].should eq 0
    counts["msgs"].should eq 0
  end
end

private class SpinnerModel
  include Tea::Model

  getter spinner = Bubbles::Spinner.new(frames: ["a", "b", "c"], fps: 100.0)
  getter frames = [] of String
  getter go_types = Set(String).new

  def init
    spinner.tick
  end

  def update(msg : Tea::Msg)
    case msg
    when Tea::GoMsg
      @go_types << msg.go_type
      cmd = spinner.update(msg)
      @frames << spinner.view
      return Tea.quit if @frames.size >= 4
      cmd
    end
  end

  def view : String
    spinner.view
  end
end

describe "Bubbles inside a program" do
  it "runs Go commands and routes Go messages back to the component" do
    model = SpinnerModel.new
    run_headless(model) { }
    model.frames.should eq ["b", "c", "a", "b"]
    model.go_types.should eq Set{"spinner.TickMsg"}
    Tea::FFI.handle_counts["msgs"].should eq 0
  end
end
