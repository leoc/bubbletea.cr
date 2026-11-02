# Paging through 100 items with the paginator (←/→ or h/l), q quits.
#
#   crystal run examples/paginator.cr
require "../src/bubbletea"

class Pages
  include Tea::Model

  ITEMS = (1..100).map { |i| "Item #{i}" }

  @paginator = Bubbles::Paginator.new(type: Bubbles::Paginator::Type::Dots, per_page: 10,
    active_dot: Lipgloss::Style.new.foreground("252").render("•"),
    inactive_dot: Lipgloss::Style.new.foreground("238").render("•"))

  def initialize
    @paginator.set_total_pages(ITEMS.size)
  end

  def update(msg : Tea::Msg)
    return Tea.quit if msg.is_a?(Tea::KeyMsg) && msg.matches?("q", "esc", "ctrl+c")
    @paginator.update(msg)
  end

  def view : String
    String.build do |s|
      s << "\n  Paginator\n\n"
      ITEMS[@paginator.slice_bounds(ITEMS.size)].each { |item| s << "  • " << item << "\n" }
      s << "\n  " << @paginator.view << "\n\n  h/l ←/→ page • q quit\n"
    end
  end
end

Tea::Program.new(Pages.new).run
