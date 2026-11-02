# Renders a markdown file to the terminal (non-interactive).
#
#   crystal run examples/glamour.cr -- [FILE.md] [STYLE]   (default: README.md, auto)
require "../src/bubbletea"

path = ARGV[0]? || File.join(__DIR__, "..", "README.md")
style = ARGV[1]? || "auto"
puts Glamour.render(File.read(path), style: style, width: 80, emoji: true)
