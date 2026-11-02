require "json"
require "wait_group"

module Tea
  class Error < Exception
  end

  enum MouseMode
    # Clicks, releases and wheel; motion only while a button is pressed.
    CellMotion
    # All mouse motion, also without a pressed button.
    AllMotion
  end

  enum InputMode
    # Standard input, or /dev/tty when stdin is not a terminal.
    Default
    # Always /dev/tty.
    TTY
    # No input at all.
    None
  end

  # Runs a model. See DESIGN.md for how the Go program and the Crystal model
  # cooperate.
  #
  # ```
  # Tea::Program.new(Counter.new, alt_screen: true).run
  # ```
  class Program(M)
    # Internal messages on the program channel.
    private class RunCmd < Msg
      getter cmd : Cmd

      def initialize(@cmd)
      end
    end

    private class Failure < Msg
      getter exception : Exception

      def initialize(@exception)
      end
    end

    @@at_exit_registered = false

    getter model : M
    # Error reported by Bubble Tea when the program stopped (if any).
    getter error : String?
    getter? killed = false
    getter? interrupted = false
    getter? running = false

    @id : UInt64 = 0
    @channel = Channel(Msg).new(256)
    @outgoing = [] of Cmd
    @notify : IO::FileDescriptor?

    # Options mirror Bubble Tea's program options.
    #
    # - *input_io*/*output_io*: use these descriptors instead of the terminal
    #   (e.g. pipes in tests).
    # - *signals*: let Bubble Tea handle SIGINT/SIGTERM.
    # - *renderer*: `false` disables rendering (`tea.WithoutRenderer`).
    def initialize(@model : M, *,
                   @alt_screen = false,
                   @mouse : MouseMode? = nil,
                   @report_focus = false,
                   @bracketed_paste = true,
                   @fps : Int32? = nil,
                   @input : InputMode = InputMode::Default,
                   @input_io : IO::FileDescriptor? = nil,
                   @output_io : IO::FileDescriptor? = nil,
                   @signals = true,
                   @catch_panics = true,
                   @renderer = true)
    end

    # Sends a message to the program from another fiber.
    def send(msg : Msg) : Nil
      @channel.send(msg)
    end

    # Asks the program to quit (from another fiber).
    def quit : Nil
      send(RunCmd.new(Tea.quit))
    end

    # Stops the program immediately and restores the terminal.
    def kill : Nil
      LibTea.bt_program_kill(@id) if @id != 0
    end

    # Runs the program until it quits and returns the model.
    def run : M
      raise Error.new("program already ran") if @id != 0
      register_at_exit
      opts = options_json
      @id = LibTea.bt_program_new(opts, opts.bytesize)
      raise Error.new("could not create program") if @id == 0

      fd = LibTea.dup(LibTea.bt_program_notify_fd(@id))
      raise Error.new("could not dup notification pipe") if fd < 0
      notify = IO::FileDescriptor.new(fd)
      @notify = notify

      process(@model.init.as?(Cmd))
      view = @model.view
      cmds = outgoing_json
      rc = LibTea.bt_program_start(@id, view, view.bytesize, cmds, cmds.bytesize)
      raise Error.new("could not start program (#{rc})") if rc != 0
      @running = true

      spawn(name: "tea-reader") { read_events(notify) }
      loop_until_exit
      @model
    ensure
      if @running
        LibTea.bt_program_kill(@id)
        @running = false
      end
      @notify.try(&.close) rescue nil
      LibTea.bt_program_free(@id) if @id != 0
    end

    private def loop_until_exit : Nil
      loop do
        msg = @channel.receive
        case msg
        when ExitMsg
          @running = false
          @error = msg.error
          @killed = msg.killed?
          @interrupted = msg.interrupted?
          return
        when Failure
          raise msg.exception
        when RunCmd
          process(msg.cmd)
          flush(nil)
        else
          begin
            process(@model.update(msg).as?(Cmd))
          ensure
            msg.release if msg.is_a?(GoMsg)
          end
          flush(@model.view)
        end
      end
    end

    # Reader fiber: waits on the notification pipe, fetches queued messages.
    private def read_events(io : IO::FileDescriptor) : Nil
      buf = Bytes.new(64)
      loop do
        n = io.read(buf)
        if json = FFI.take(LibTea.bt_program_poll(@id))
          JSON.parse(json).as_a.each do |raw|
            next unless msg = Msg.from_wire(raw)
            @channel.send(msg)
            return if msg.is_a?(ExitMsg)
          end
        end
        return if n == 0
      end
    rescue IO::Error
      # pipe closed during shutdown
    end

    # Handles a command returned by init/update: control commands are queued
    # for Go, everything else runs in fibers.
    private def process(cmd : Cmd?) : Nil
      case cmd
      when nil
      when BatchCmd
        cmd.cmds.each { |c| process(c) }
      when ControlCmd, GoCmd
        @outgoing << cmd
      else
        spawn { execute(cmd) }
      end
    end

    # Runs a command to completion inside the current fiber.
    private def execute(cmd : Cmd) : Nil
      case cmd
      when AsyncCmd
        deliver(cmd.proc.call)
      when TickCmd
        span = cmd.span
        if cmd.align?
          now = Time.utc
          offset = (now - Time::UNIX_EPOCH).total_nanoseconds.to_i64 % span.total_nanoseconds.to_i64
          sleep(span - offset.nanoseconds)
        else
          sleep(span)
        end
        deliver(cmd.proc.call(Time.local))
      when MsgCmd
        deliver(cmd.msg)
      when BatchCmd
        WaitGroup.wait do |wg|
          cmd.cmds.each { |c| wg.spawn { execute(c) } }
        end
      when SequenceCmd
        cmd.cmds.each { |c| execute(c) }
      when ControlCmd, GoCmd
        deliver(RunCmd.new(cmd))
      end
    rescue ex
      deliver(Failure.new(ex))
    end

    private def deliver(msg : Msg?) : Nil
      @channel.send(msg) if msg && @running
    rescue Channel::ClosedError
    end

    private def flush(view : String?) : Nil
      return unless @running
      cmds = outgoing_json
      return if view.nil? && cmds.empty?
      if view
        LibTea.bt_program_update(@id, view, view.bytesize, cmds, cmds.bytesize)
      else
        LibTea.bt_program_update(@id, Pointer(UInt8).null, -1, cmds, cmds.bytesize)
      end
    end

    private def outgoing_json : String
      return "" if @outgoing.empty?
      json = JSON.build do |io|
        io.array do
          @outgoing.each do |c|
            case c
            when ControlCmd then c.to_wire(io)
            when GoCmd      then c.to_wire(io)
            end
          end
        end
      end
      @outgoing.clear
      json
    end

    private def options_json : String
      JSON.build do |j|
        j.object do
          j.field "alt_screen", @alt_screen
          case @mouse
          when MouseMode::CellMotion then j.field "mouse", "cell"
          when MouseMode::AllMotion  then j.field "mouse", "all"
          end
          j.field "report_focus", @report_focus
          j.field "bracketed_paste", @bracketed_paste
          j.field "fps", @fps if @fps
          if io = @input_io
            j.field "input", "fd"
            j.field "input_fd", io.fd
          else
            j.field "input", @input.to_s.downcase
          end
          j.field "output_fd", @output_io.try(&.fd) || -1
          j.field "signals", @signals
          j.field "catch_panics", @catch_panics
          j.field "renderer", @renderer
        end
      end
    end

    private def register_at_exit : Nil
      return if @@at_exit_registered
      @@at_exit_registered = true
      at_exit { LibTea.bt_shutdown }
    end
  end
end
