require "./tea/lib"
require "./tea/msg"
require "./tea/cmd"
require "./tea/model"
require "./tea/program"
require "./lipgloss"
require "./bubbles"
require "./glamour"

# Crystal bindings for Bubble Tea (see README.md and DESIGN.md).
module Tea
  VERSION = "0.2.0"

  # Versions of the wrapped Go modules ("bubbletea", "lipgloss", "go", ...).
  def self.upstream_versions : Hash(String, String)
    Hash(String, String).from_json(FFI.take!(LibTea.bt_versions))
  end
end
