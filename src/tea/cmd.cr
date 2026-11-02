module Tea
  # A command: work the runtime performs on behalf of the model, usually
  # producing a message. Build commands with the `Tea.*` helpers.
  abstract class Cmd
  end

  # Runs a block in its own fiber; a returned `Msg` is sent to `update`.
  class AsyncCmd < Cmd
    getter proc : Proc(Msg?)

    def initialize(@proc)
    end
  end

  # Waits `span`, then calls the block with the current time.
  class TickCmd < Cmd
    getter span : Time::Span
    getter proc : Proc(Time, Msg?)
    getter? align : Bool

    def initialize(@span, @proc, @align = false)
    end
  end

  # Delivers a message right away.
  class MsgCmd < Cmd
    getter msg : Msg

    def initialize(@msg)
    end
  end

  # Runs commands concurrently.
  class BatchCmd < Cmd
    getter cmds : Array(Cmd)

    def initialize(@cmds)
    end
  end

  # Runs commands one after another; each waits for the previous one.
  class SequenceCmd < Cmd
    getter cmds : Array(Cmd)

    def initialize(@cmds)
    end
  end

  # A Bubble Tea built-in command executed by the Go program (quit, alt
  # screen, mouse modes, window title, println, ...).
  class ControlCmd < Cmd
    getter type : String
    getter text : String?

    def initialize(@type, @text = nil)
    end

    def to_wire(io : JSON::Builder) : Nil
      io.object do
        io.field "type", type
        io.field "text", text if text
      end
    end
  end

  # A Go command returned by a Bubbles component (e.g. a spinner tick). The
  # Go program runs it; its result arrives as a `GoMsg`.
  class GoCmd < Cmd
    getter handle : UInt64

    def initialize(@handle)
    end

    def to_wire(io : JSON::Builder) : Nil
      io.object do
        io.field "type", "go"
        io.field "handle", handle
      end
    end

    def finalize
      LibTea.bt_cmd_free(handle)
    end
  end

  # --- helpers ---------------------------------------------------------

  # Runs the block in a fiber and sends its result (if it is a `Msg`).
  #
  # ```
  # Tea.cmd { FetchedMsg.new(HTTP::Client.get(url).body) }
  # ```
  def self.cmd(&block : -> Msg?) : Cmd
    AsyncCmd.new(block)
  end

  # Delivers `msg` to `update` as a command.
  def self.msg(msg : Msg) : Cmd
    MsgCmd.new(msg)
  end

  # Calls the block once after `span`.
  #
  # ```
  # Tea.tick(1.second) { |t| TickMsg.new(t) }
  # ```
  def self.tick(span : Time::Span, &block : Time -> Msg?) : Cmd
    TickCmd.new(span, block)
  end

  # Like `tick`, but fires in sync with the system clock (e.g. on the full
  # second for `1.second`).
  def self.every(span : Time::Span, &block : Time -> Msg?) : Cmd
    TickCmd.new(span, block, align: true)
  end

  # Runs commands concurrently. `nil` entries are ignored.
  def self.batch(*cmds : Cmd?) : Cmd?
    batch(cmds.to_a)
  end

  def self.batch(cmds : Enumerable(Cmd?)) : Cmd?
    list = [] of Cmd
    cmds.each { |c| list << c if c }
    case list.size
    when 0 then nil
    when 1 then list.first
    else        BatchCmd.new(list)
    end
  end

  # Runs commands one after another. `nil` entries are ignored.
  def self.sequence(*cmds : Cmd?) : Cmd?
    sequence(cmds.to_a)
  end

  def self.sequence(cmds : Enumerable(Cmd?)) : Cmd?
    list = [] of Cmd
    cmds.each { |c| list << c if c }
    list.empty? ? nil : SequenceCmd.new(list)
  end

  {% for name in %w(quit suspend interrupt clear_screen enter_alt_screen exit_alt_screen
                   enable_mouse_cell_motion enable_mouse_all_motion disable_mouse
                   hide_cursor show_cursor enable_bracketed_paste disable_bracketed_paste
                   enable_report_focus disable_report_focus window_size) %}
    # Bubble Tea's `tea.{{ name.camelcase.id }}` command.
    def self.{{ name.id }} : Cmd
      ControlCmd.new({{ name }})
    end
  {% end %}

  # Sets the terminal window title.
  def self.set_window_title(title : String) : Cmd
    ControlCmd.new("set_window_title", title)
  end

  # Prints a line above the program (not in alt screen mode).
  def self.println(text : String) : Cmd
    ControlCmd.new("println", text)
  end
end
