module Bubbles
  # A progress bar (`bubbles/progress`), optionally animated.
  #
  # `view_as(0.5)` renders statically. For the spring animation call
  # `set_percent` and return its command, and forward messages to `update`.
  class Progress < Component
    def initialize(*, width : Int32? = nil, gradient : {String, String}? = nil,
                   scale_gradient : Bool? = nil, solid_fill : String? = nil,
                   full : Char? = nil, empty : Char? = nil, empty_color : String? = nil,
                   show_percentage : Bool? = nil, percent_format : String? = nil,
                   percentage_style : Lipgloss::Style? = nil, spring : {Float64, Float64}? = nil)
      super("progress", {width: width, gradient: gradient.try(&.to_a), scale_gradient: scale_gradient,
                         solid_fill: solid_fill, full: full.try(&.to_s), empty: empty.try(&.to_s),
                         empty_color: empty_color, show_percentage: show_percentage,
                         percent_format: percent_format, percentage_style: percentage_style,
                         spring: spring.try(&.to_a)})
    end

    def percent : Float64
      call("percent").as_f
    end

    # Animates to *value* (0.0..1.0); return the command from `update`.
    def set_percent(value : Float64) : Tea::Cmd?
      call_cmd("set_percent", value)
    end

    def incr_percent(value : Float64) : Tea::Cmd?
      call_cmd("incr_percent", value)
    end

    def decr_percent(value : Float64) : Tea::Cmd?
      call_cmd("decr_percent", value)
    end

    # Renders the bar at *percent* without animation.
    def view_as(percent : Float64) : String
      call("view_as", percent).as_s
    end

    def animating? : Bool
      call("animating").as_bool
    end

    def width=(value : Int32) : Int32
      configure(width: value)
      value
    end
  end
end
