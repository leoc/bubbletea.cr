# A small form: tab/shift+tab move between fields, enter submits, esc quits.
#
#   crystal run examples/textinput.cr
require "../src/bubbletea"

class Form
  include Tea::Model

  FOCUSED = Lipgloss::Style.new.foreground("205")
  BLURRED = Lipgloss::Style.new.foreground("240")

  getter inputs : Array(Bubbles::TextInput)
  getter? submitted = false
  @focus = 0

  def initialize
    @inputs = [
      Bubbles::TextInput.new(placeholder: "Nickname", char_limit: 32, width: 30),
      Bubbles::TextInput.new(placeholder: "Email", char_limit: 64, width: 30,
        suggestions: ["arthur@example.com", "tea@example.com"], show_suggestions: true),
      Bubbles::TextInput.new(placeholder: "Password", width: 30,
        echo_mode: Bubbles::TextInput::EchoMode::Password, echo_character: '•'),
    ]
  end

  def init
    focus(0)
  end

  private def focus(index) : Tea::Cmd?
    @focus = index % @inputs.size
    cmd = nil
    @inputs.each_with_index do |input, i|
      if i == @focus
        cmd = input.focus
        input.configure(prompt_style: FOCUSED, text_style: FOCUSED)
      else
        input.blur
        input.configure(prompt_style: BLURRED, text_style: BLURRED)
      end
    end
    cmd
  end

  def update(msg : Tea::Msg)
    if msg.is_a?(Tea::KeyMsg)
      case msg.key
      when "esc", "ctrl+c"   then return Tea.quit
      when "tab", "down"     then return focus(@focus + 1)
      when "shift+tab", "up" then return focus(@focus - 1)
      when "enter"
        if @focus == @inputs.size - 1
          @submitted = true
          return Tea.quit
        end
        return focus(@focus + 1)
      end
    end
    # only the focused input reacts to keys; all get blink messages
    Tea.batch(@inputs.map(&.update(msg)))
  end

  def view : String
    String.build do |s|
      s << "\n"
      @inputs.each { |i| s << "  " << i.view << "\n" }
      s << "\n  " << BLURRED.render("tab: next • enter: submit • esc: quit") << "\n"
    end
  end
end

form = Tea::Program.new(Form.new).run
puts "Hello #{form.inputs[0].value} <#{form.inputs[1].value}>" if form.submitted?
