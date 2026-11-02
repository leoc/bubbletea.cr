module Bubbles
  # Renders key binding help (`bubbles/help`).
  #
  # ```
  # help = Bubbles::Help.new(width: 80)
  # help.view(keymap) # keymap includes Bubbles::Key::KeyMap
  # ```
  class Help < Component
    getter? show_all : Bool

    # Styles keys: `ellipsis`, `short_key`, `short_desc`, `short_separator`,
    # `full_key`, `full_desc`, `full_separator`.
    def initialize(*, width : Int32? = nil, @show_all = false, short_separator : String? = nil,
                   full_separator : String? = nil, ellipsis : String? = nil,
                   styles : Hash(String, Lipgloss::Style)? = nil)
      super("help", {width: width, show_all: @show_all, short_separator: short_separator,
                     full_separator: full_separator, ellipsis: ellipsis, styles: styles})
    end

    def show_all=(value : Bool) : Bool
      call("configure", {show_all: value})
      @show_all = value
    end

    def width=(value : Int32) : Int32
      call("configure", {width: value})
      value
    end

    # Short or full help, depending on `show_all?`.
    def view(keymap : Key::KeyMap) : String
      show_all? ? full_help_view(keymap.full_help) : short_help_view(keymap.short_help)
    end

    def short_help_view(bindings : Array(Key::Binding)) : String
      call("short_help_view", bindings).as_s
    end

    def full_help_view(groups : Array(Array(Key::Binding))) : String
      call("full_help_view", groups).as_s
    end
  end
end
