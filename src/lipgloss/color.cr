require "json"

module Lipgloss
  # A colour that depends on the terminal background.
  #
  # ```
  # Lipgloss::AdaptiveColor.new(light: "#333333", dark: "#eeeeee")
  # ```
  record AdaptiveColor, light : String, dark : String do
    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "light", light
        json.field "dark", dark
      end
    end
  end

  # Exact values per colour profile, no automatic degradation.
  record CompleteColor, true_color : String, ansi256 : String, ansi : String do
    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "true_color", true_color
        json.field "ansi256", ansi256
        json.field "ansi", ansi
      end
    end
  end

  # A `CompleteColor` per background.
  record CompleteAdaptiveColor, light : CompleteColor, dark : CompleteColor do
    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "light", light
        json.field "dark", dark
      end
    end
  end

  # A colour: `"#ff00ff"` (true colour), `"201"` (ANSI 256), `"5"` (ANSI),
  # `""` (no colour) or one of the colour records.
  alias Color = String | AdaptiveColor | CompleteColor | CompleteAdaptiveColor

  # Terminal colour profiles (values match termenv.Profile).
  enum ColorProfile
    TrueColor = 0
    ANSI256   = 1
    ANSI      = 2
    Ascii     = 3
  end

  # Forces the colour profile (detected from stdout by default).
  def self.color_profile=(profile : ColorProfile) : ColorProfile
    LibTea.bt_lipgloss_set_color_profile(profile.value)
    profile
  end

  def self.color_profile : ColorProfile
    ColorProfile.new(LibTea.bt_lipgloss_color_profile)
  end

  # Overrides background detection for `AdaptiveColor`.
  def self.dark_background=(dark : Bool) : Bool
    LibTea.bt_lipgloss_set_dark_background(dark ? 1 : 0)
    dark
  end

  def self.dark_background? : Bool
    LibTea.bt_lipgloss_has_dark_background != 0
  end
end
