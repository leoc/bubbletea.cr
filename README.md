# bubbletea.cr

Crystal bindings for [Charm](https://charm.sh)'s terminal UI stack:

- [Bubble Tea](https://github.com/charmbracelet/bubbletea): the Elm-style
  program loop (`Tea`)
- [Lip Gloss](https://github.com/charmbracelet/lipgloss): styles, layout,
  tables (`Lipgloss`)

The Go libraries are compiled into one C shared library
(`libbubbletea_go.so`) and bound through Crystal's `lib` FFI. Bubble Tea's
real program, renderer and input parser run in Go; your model, `update`,
`view` and commands run in Crystal. See [DESIGN.md](DESIGN.md) for the
architecture.

```crystal
require "bubbletea"

class Counter
  include Tea::Model

  STYLE = Lipgloss::Style.new.bold.foreground("#FF5F87").padding(0, 1)

  getter count = 0

  def update(msg : Tea::Msg)
    case msg
    when Tea::KeyMsg
      case msg.key
      when "q", "ctrl+c" then return Tea.quit
      when "up", "+"     then @count += 1
      when "down", "-"   then @count -= 1
      end
    end
  end

  def view : String
    "Count:#{STYLE.render(@count.to_s)}\n\n(↑/↓, q to quit)\n"
  end
end

model = Tea::Program.new(Counter.new).run
puts "Final count: #{model.count}"
```

## Installation

Linux only for now (x86_64, aarch64).

### 1. The shard

```yaml
# shard.yml
dependencies:
  bubbletea:
    git: https://github.com/leoc/bubbletea.cr
    version: ~> 0.1
```

`shards install` runs `make lib` as postinstall: with Go ≥ 1.24 and a C
compiler on the `PATH` it builds `lib/bubbletea/go/build/libbubbletea_go.so`,
and the shard links it with an rpath automatically.

### 2. Or the shared library from Nix

Without Go, build the library with the flake and point the compiler at it:

```sh
nix build github:leoc/bubbletea.cr#libbubbletea-go
export BUBBLETEA_LIB_DIR=$PWD/result/lib   # read at compile time, adds -L and an rpath
crystal build src/app.cr
```

Any other way works too, as long as the linker finds `-lbubbletea_go`
(`CRYSTAL_LIBRARY_PATH`/`LIBRARY_PATH`) and the loader finds the `.so` at
run time (`LD_LIBRARY_PATH` or an rpath).

## Usage

### Models, messages, commands

A model includes `Tea::Model` and implements `update(msg)` and `view`;
`init` is optional. `update` mutates the model and returns a command or
`nil`.

| Message | When |
|---|---|
| `Tea::KeyMsg` | key press; match on `msg.key` (`"a"`, `"ctrl+c"`, `"enter"`, `"alt+x"`, `"up"`) |
| `Tea::MouseMsg` | mouse (`mouse: Tea::MouseMode::CellMotion` / `AllMotion`); `x`, `y`, `button`, `action` |
| `Tea::WindowSizeMsg` | at start and on resize |
| `Tea::FocusMsg`, `Tea::BlurMsg` | with `report_focus: true` |
| your own `class Foo < Tea::Msg` | returned by your commands |

| Command | |
|---|---|
| `Tea.cmd { FooMsg.new }` | custom async work in its own fiber; the result goes to `update` |
| `Tea.tick(1.second) { \|t\| TickMsg.new(t) }` | once after a delay |
| `Tea.every(1.second) { \|t\| ... }` | like `tick`, aligned to the clock |
| `Tea.batch(a, b)` / `Tea.sequence(a, b)` | concurrently / one after another |
| `Tea.msg(msg)` | deliver a message |
| `Tea.quit`, `Tea.enter_alt_screen`, `Tea.exit_alt_screen`, `Tea.enable_mouse_cell_motion`, `Tea.disable_mouse`, `Tea.set_window_title(t)`, `Tea.println(t)`, `Tea.clear_screen`, `Tea.window_size`, ... | Bubble Tea's built-ins |

```crystal
Tea::Program.new(model,
  alt_screen: true,                       # full screen
  mouse: Tea::MouseMode::CellMotion,      # or AllMotion
  report_focus: false,
  fps: 60,
).run
```

`Program#send(msg)` and `Program#quit` work from other fibers.
`Program#interrupted?` is true after a `SIGINT`.

### Lip Gloss

Styles are values: every setter returns a copy.

```crystal
box = Lipgloss::Style.new
  .border(:rounded)
  .border_foreground(Lipgloss::AdaptiveColor.new(light: "#874BFD", dark: "#7D56F4"))
  .padding(1, 2)
  .width(30)
  .align(:center)

puts box.render("Hello")
puts Lipgloss.join_horizontal(:top, box.render("left"), box.render("right"))
puts Lipgloss.place(80, 20, :center, :center, "centred")

puts Lipgloss::Table.new
  .border(:normal)
  .headers("Name", "Lang")
  .row("Bubble Tea", "Go")
  .row("bubbletea.cr", "Crystal")
  .style_func { |row, _col| row == Lipgloss::Table::HEADER_ROW ? Lipgloss::Style.new.bold : nil }
```

Supported: bold/italic/underline/strikethrough/reverse/blink/faint,
foreground/background (hex, ANSI 256, ANSI, `AdaptiveColor`, `CompleteColor`,
`CompleteAdaptiveColor`), width/height/max sizes, horizontal and vertical
alignment, padding and margin (CSS shorthand and per side), margin
background, borders (all Lip Gloss borders, custom `Lipgloss::Border`, per
side, colours), inline, tab width, transform (`:upper`/`:lower`),
`set_string`, `inherit`, frame sizes; `join_horizontal`, `join_vertical`,
`place*`, `width`, `height`, `size`; tables with per-cell styles, border
toggles, width/height/offset/wrap. `Lipgloss.color_profile=` and
`Lipgloss.dark_background=` override detection.

## Examples

```sh
nix develop          # Go, Crystal, shards, make
make lib
crystal run examples/counter.cr
crystal run examples/list.cr      # cursor, selection, mouse wheel and clicks
crystal run examples/layout.cr    # alt screen, tabs, table, clock, async loading
```

## Development

```sh
nix develop
make lib     # go/build/libbubbletea_go.so
make spec    # crystal spec (headless, no TTY needed)
nix flake check   # builds the library with Nix, runs specs, compiles examples, checks formatting
```

After changing `go/go.mod`, update `vendorHash` in `flake.nix` (`nix build`
prints the new hash).

## Limitations

- Linux only so far; macOS needs a `.dylib` build and `install_name` instead
  of the rpath (untested).
- Wraps the v1 API line (Bubble Tea v1.3, Lip Gloss v1.1).
  `charm.land/*/v2` is not wrapped yet.
- The model is mutable; `update` returns only a command.
- Several runes typed faster than one read arrive as one `KeyMsg` with
  `runes` = `"ab"` (Bubble Tea behaviour).
- `tea.Exec`/`tea.ExecProcess` (handing the terminal to a subprocess) are
  not wrapped yet.
- A crash inside Go code that is not a Go panic (e.g. a nil dereference) is
  reported by Crystal's segfault handler, not as a Go panic; see DESIGN.md.
- Every value crossing the boundary is copied; very large views (megabytes)
  per frame cost a few copies.

## License

MIT, see [LICENSE](LICENSE), including the notices of the wrapped Charm
libraries.
