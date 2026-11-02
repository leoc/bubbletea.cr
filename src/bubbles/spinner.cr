module Bubbles
  # An animated spinner (`bubbles/spinner`).
  #
  # Start it by returning `spinner.tick` from `init`, and forward messages to
  # `spinner.update` in your `update`.
  class Spinner < Component
    enum Type
      Line
      Dot
      MiniDot
      Jump
      Pulse
      Points
      Globe
      Moon
      Monkey
      Meter
      Hamburger
      Ellipsis
    end

    def initialize(type : Type = Type::Line, *, frames : Array(String)? = nil, fps : Float64? = nil,
                   style : Lipgloss::Style? = nil)
      super("spinner", {type: type.to_s.underscore, frames: frames, fps: fps, style: style})
    end

    # The command that starts the animation.
    def tick : Tea::Cmd?
      call_cmd("tick")
    end

    def id : Int32
      call("id").as_i
    end
  end
end
