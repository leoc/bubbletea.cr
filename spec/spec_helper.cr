require "spec"
require "../src/bubbletea"

# Specs run without a terminal: force a known colour profile and background.
Lipgloss.color_profile = Lipgloss::ColorProfile::Ascii
Lipgloss.dark_background = true

def with_color_profile(profile : Lipgloss::ColorProfile, &)
  old = Lipgloss.color_profile
  Lipgloss.color_profile = profile
  yield
ensure
  Lipgloss.color_profile = old.not_nil!
end

def strip_ansi(s : String) : String
  s.gsub(/\e\[[0-9;?]*[a-zA-Z]/, "")
end
