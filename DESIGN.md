# Design

bubbletea.cr binds the Charm TUI stack (Bubble Tea, Lip Gloss, Bubbles,
Glamour) to Crystal. The Go libraries are compiled into one C shared library
(`libbubbletea_go.so`, `go build -buildmode=c-shared`, functions exported with
cgo `//export`), and Crystal talks to it through a `lib LibTea` FFI block with
an idiomatic Crystal API on top.

## Prior art: the Ruby bindings

Marco Roth's Charm Ruby gems (`bubbletea-ruby`, `lipgloss-ruby`,
`bubbles-ruby`, `glamour-ruby`) also wrap Go as `c-shared` libraries. Reading
their source showed three different strategies:

| Gem | What lives in Go | What lives in Ruby |
|---|---|---|
| bubbletea-ruby | terminal primitives (raw mode, alt screen, mouse modes), an input reader, its *own* key/mouse parser and line renderer, all exported as small C functions; key events cross the boundary as JSON | the whole program loop (`Runner`): polls Go for input with a timeout, runs `update`/`view`, executes commands in Ruby threads, handles `SIGWINCH` itself |
| lipgloss-ruby | every `lipgloss.Style` lives in a Go map behind a `uint64` handle; each builder call allocates a *new* handle (Lip Gloss styles are values) | thin wrapper objects holding the handle |
| bubbles-ruby | nothing | a pure-Ruby re-implementation of the components |
| glamour-ruby | `glamour.Render` and friends | thin wrapper |

Their key insight, which this project keeps: **Go never calls back into the
host language.** Ruby (like Crystal) has its own scheduler and GC, and a
foreign Go thread entering the interpreter is the classic way to crash such
bindings.

What this project does differently:

- bubbletea-ruby does not use Bubble Tea's `tea.Program` at all (it
  re-implements input parsing and rendering in Go and the loop in Ruby). Here
  the real `tea.Program` runs, so we get Bubble Tea's renderer, input parser,
  mouse/focus/paste handling, `SIGWINCH`/`SIGINT`/`SIGTERM` handling and
  terminal restore for free, and stay current with upstream fixes.
- Instead of a Go handle per Lip Gloss style, a Crystal `Lipgloss::Style` is a
  plain Crystal value that serialises to JSON; Go turns the JSON into a
  `lipgloss.Style` (cached) when rendering. No handles, no leaks, and style
  building is testable without the library.
- Bubbles are *wrapped*, not re-implemented: the real Go components live
  behind handles, so filtering in `list`, editing in `textinput`/`textarea`,
  spring animation in `progress` etc. behave exactly like upstream.

## Architecture: Go runs the program, Crystal owns the model

```
 Crystal (main thread, fibers)                 Go (own threads, goroutines)
 ─────────────────────────────                 ─────────────────────────────
 Tea::Program#run                              tea.Program (proxy model)
   model.init / update / view                    renderer, input parser,
   commands: Tick, Batch, Sequence,              signals, terminal state
     Tea.cmd { } (fibers)                         │
                                                  │ every tea.Msg the proxy
   reader fiber ◄── wait_readable(pipe) ◄──────── │ receives is encoded as JSON,
       │            bt_program_poll() ◄────────── │ queued, and 1 byte is
       ▼                                          │ written to a pipe
   Channel(Msg) ──► update ──► view               │
       │                                          │
       └─ bt_program_update(view, cmds_json) ───► p.Send(frameMsg)
                                                   proxy.Update stores view,
                                                   returns tea.Quit,
                                                   tea.EnterAltScreen, ...
```

The two options considered:

1. **Go drives, calls back into Crystal** (`tea.Program` with a model whose
   `Update`/`View` are C function pointers into Crystal). Rejected: Bubble Tea
   calls `Update`/`View` from its event-loop goroutine and runs commands on
   arbitrary goroutines, i.e. on OS threads Crystal's runtime does not know.
   Crystal fibers, the Boehm GC and exception unwinding are not safe there.
   It would also block the Crystal thread inside `Program.Run`, so Crystal
   fibers (async commands, timers) would never run.
2. **Crystal drives, Go is a pure service** (this design). Every FFI call goes
   from the Crystal main thread into Go and returns quickly (a mutex and a
   copy). Go *notifies* Crystal by writing to a pipe; Crystal waits on the
   pipe's read end with its own event loop (`IO#wait_readable`), so while it
   waits other fibers keep running. No Go code ever runs on a Crystal thread
   longer than a function call, and no Crystal code ever runs on a Go thread.

The Go side keeps a *proxy model*. Its `Update`:

- for an internal `frameMsg` (sent by Crystal): stores the new view string and
  returns the requested Bubble Tea commands (`tea.Quit`, `tea.EnterAltScreen`,
  `tea.SetWindowTitle`, `tea.Println`, ... or a Go command produced by a
  Bubbles component);
- for every other message (keys, mouse, window size, focus, paste, component
  messages): encodes it and queues it for Crystal.

Its `View` returns the last view Crystal sent. Bubble Tea's renderer
throttles to its frame rate, so pushing a view after every Crystal update is
cheap.

### Messages (Go → Crystal)

Known messages are JSON-encoded (`key`, `mouse`, `window_size`, `focus`,
`blur`, `exit`) and decoded into Crystal classes (`Tea::KeyMsg`,
`Tea::MouseMsg`, `Tea::WindowSizeMsg`, ...). Any other Go message (spinner
ticks, list filter results, cursor blinks...) is stored in a Go registry and
crosses as `{"type":"go","handle":N,"go_type":"spinner.TickMsg"}` →
`Tea::GoMsg`. Passing a `GoMsg` to a Bubbles component hands the handle back
to Go, which looks up the original message. The runtime frees the handle
after the model's `update` returns, so a `GoMsg` is only valid during the
`update` call that received it (forward it to all components there).

### Commands

Commands are Crystal values (`Tea::Cmd`), not closures handed to Go:

| Command | Executed by |
|---|---|
| `Tea.cmd { ... }` (custom async), `Tea.tick`, `Tea.every` | a Crystal fiber; the returned `Tea::Msg` is sent to the program channel |
| `Tea.batch`, `Tea.sequence` | Crystal; batch spawns concurrently, sequence runs one after the other in a fiber and waits for nested batches |
| `Tea.quit`, `Tea.enter_alt_screen`, mouse modes, `Tea.set_window_title`, `Tea.println`, ... | Go: sent with the next view in `bt_program_update` and mapped to the real Bubble Tea command |
| `Tea::GoCmd` (returned by Bubbles components) | Go: Bubble Tea runs the stored `tea.Cmd` in a goroutine; its result returns as a `GoMsg` |

Messages from all sources go through one `Channel(Tea::Msg)`, so `update` is
always called on one fiber, one message at a time (same guarantee as Go).

The model is a mutable Crystal object (`include Tea::Model`, `update` returns
`Tea::Cmd?`). Returning a new model like Go/Elm does buys little in Crystal and
would force a generic program type.

## Lip Gloss

`Lipgloss::Style` is a Crystal class with value semantics: every builder
method (`bold`, `foreground`, `padding`, `border`, ...) returns a modified copy,
like Lip Gloss itself. It serialises to JSON (memoised), and
`bt_style_render(json, text)` builds the Go style and renders. Go caches built
styles by their JSON, so re-rendering the same style does not re-parse.
Colours are `"#ff00ff"`/`"201"` strings, `Lipgloss::AdaptiveColor`
(light/dark), `Lipgloss::CompleteColor` and `CompleteAdaptiveColor`.

Layout helpers (`join_horizontal`, `join_vertical`, `place`, `width`,
`height`) and `Lipgloss::Table` (`lipgloss/table`) are single calls with JSON
arguments. Table style functions are evaluated in Crystal for every cell before
the call (no callbacks), the distinct styles are deduplicated and sent once.

## Bubbles and Glamour

Each component (`list`, `table`, `textinput`, `textarea`, `viewport`,
`spinner`, `progress`, `help`, `paginator`) is a Go value in a registry
behind a `uint64` handle. The C ABI for all components is five functions:

```
bt_component_new(kind, options_json) -> handle
bt_component_update(handle, msg_json) -> cmd handle (0 = none)
bt_component_view(handle) -> char*
bt_component_call(handle, method, args_json) -> result_json
bt_component_free(handle)
```

Crystal wrapper classes (`Bubbles::TextInput`, `Bubbles::List(T)`, ...) map
methods to `call`. Crystal messages are converted back to Go messages from
their JSON (`KeyMsg`, `MouseMsg`, `WindowSizeMsg`, `GoMsg`), so components
can be driven headless in specs. Key bindings (`Bubbles::Key::Binding`) and
key maps are plain Crystal; `Bubbles::Help` sends them to Go for rendering.

List items stay Crystal objects: Go only sees `{id, title, description,
filter_value}`, and `selected_item` maps the id back to the Crystal object.

Glamour is one call: `bt_glamour_render(markdown, options_json)`. Its `auto`
style uses Lip Gloss' cached background detection instead of
`glamour.WithAutoStyle`, which would query the terminal again: while a
program owns stdin the answer never reaches the query and the render blocks
until the query times out.

## Memory ownership

- Crystal → Go strings are passed as pointer + length. Go copies them
  (`C.GoStringN`) before returning and never keeps C pointers.
- Go → Crystal strings are `C.CString` (C heap). Crystal copies them into a
  `String` and immediately calls `bt_free`. One helper (`LibTea.take`) does
  this, so no call site frees by hand.
- Nothing crosses as a Go pointer (cgo pointer rules). Programs, components,
  stored commands and stored messages are `uint64` handles into Go maps.
  Crystal wrappers free them in `finalize` (and the runtime frees message
  handles after dispatch); freeing is idempotent.

## Threads, fibers, signals

- Crystal runs single-threaded (no `-Dpreview_mt` needed). All FFI calls are
  made from the Crystal main thread and return immediately; the only waiting
  happens in Crystal's event loop on the notification pipe.
- The Go runtime starts its own threads when the library is loaded; Go never
  calls into Crystal (no function pointers are exported to Go).
- Bubble Tea installs its handlers for `SIGWINCH` (window size), `SIGINT` and
  `SIGTERM` (quit, terminal restore). Crystal does not trap those signals while
  a program runs. A `SIGINT` ends the program with `Program#interrupted?`.
- Crystal installs its own `SIGSEGV`/`SIGBUS` handlers (stack overflow
  detection) after the Go library is loaded, so a nil dereference *inside Go*
  is reported by Crystal instead of turning into a Go panic. Go panics in
  normal code paths are still caught by Bubble Tea, which restores the
  terminal.

## Terminal restore on crash

- `Program#run` wraps the loop in `ensure`: if `update`/`view` or a command
  raises, it calls `bt_program_kill`, which kills the Go program and waits
  (bounded) until Bubble Tea has restored the terminal; then the exception
  propagates and prints on a sane terminal.
- An `at_exit` hook kills every program still running (e.g. `exit` from
  inside `update`).
- Exceptions in command fibers are caught and re-raised on the main loop, so
  they take the same path.
- A hard crash of the process (segfault, `SIGKILL`) cannot be handled; `reset`
  fixes the terminal.

## Versions

Pinned in `go/go.mod`: Bubble Tea v1.3.10, Lip Gloss v1.1.x, Bubbles v1.0.0,
Glamour v1.0.0 (the v1 API line; `charm.land/*/v2` exists and is a possible
later migration).
