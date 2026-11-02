package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"errors"
	"os"
	"sync"
	"syscall"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

var programs = newRegistry[*program]()

// programOptions is the JSON accepted by bt_program_new.
type programOptions struct {
	AltScreen      bool   `json:"alt_screen"`
	Mouse          string `json:"mouse"` // "", "cell", "all"
	ReportFocus    bool   `json:"report_focus"`
	BracketedPaste *bool  `json:"bracketed_paste"`
	FPS            int    `json:"fps"`
	Input          string `json:"input"` // "default", "tty", "none", "fd"
	InputFD        int    `json:"input_fd"`
	OutputFD       int    `json:"output_fd"` // -1: stdout
	Signals        *bool  `json:"signals"`
	CatchPanics    *bool  `json:"catch_panics"`
	Renderer       *bool  `json:"renderer"`
}

// frameMsg carries a new view and commands from Crystal into the event loop.
type frameMsg struct {
	view    string
	hasView bool
	cmd     tea.Cmd
}

type program struct {
	id   uint64
	opts programOptions
	tp   *tea.Program

	mu       sync.Mutex
	queue    []json.RawMessage
	notified bool
	started  bool
	finished bool

	notifyR, notifyW int
	done             chan struct{}
	files            []*os.File

	// frames waiting to be sent to the event loop, in order
	frameMu   sync.Mutex
	frames    []frameMsg
	frameWake chan struct{}
}

// proxy is the tea.Model that stands in for the Crystal model.
type proxy struct {
	st   *program
	view string
	init tea.Cmd
}

func (m *proxy) Init() tea.Cmd { return m.init }

func (m *proxy) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if f, ok := msg.(frameMsg); ok {
		if f.hasView {
			m.view = f.view
		}
		return m, f.cmd
	}
	if enc, ok := encodeMsg(msg); ok {
		m.st.push(enc)
	}
	return m, nil
}

func (m *proxy) View() string { return m.view }

// push queues a message for Crystal and wakes it through the pipe.
func (st *program) push(m msgJSON) {
	b, err := json.Marshal(m)
	if err != nil {
		return
	}
	st.mu.Lock()
	st.queue = append(st.queue, b)
	wake := !st.notified
	st.notified = true
	st.mu.Unlock()
	if wake {
		_, _ = syscall.Write(st.notifyW, []byte{1})
	}
}

func (st *program) sendLoop() {
	for {
		select {
		case <-st.done:
			return
		case <-st.frameWake:
		}
		for {
			st.frameMu.Lock()
			if len(st.frames) == 0 {
				st.frameMu.Unlock()
				break
			}
			f := st.frames[0]
			st.frames = st.frames[1:]
			st.frameMu.Unlock()
			st.tp.Send(f) // returns early once the program has stopped
		}
	}
}

func (st *program) closeFiles() {
	for _, f := range st.files {
		_ = f.Close()
	}
	st.files = nil
}

// cmdJSON is one command requested by Crystal.
type cmdJSON struct {
	Type   string `json:"type"`
	Text   string `json:"text"`
	Handle uint64 `json:"handle"`
}

func buildCmd(data []byte) tea.Cmd {
	if len(data) == 0 {
		return nil
	}
	var list []cmdJSON
	if err := json.Unmarshal(data, &list); err != nil {
		return nil
	}
	var controls, async []tea.Cmd
	for _, c := range list {
		var cmd tea.Cmd
		switch c.Type {
		case "quit":
			cmd = tea.Quit
		case "suspend":
			cmd = tea.Suspend
		case "interrupt":
			cmd = tea.Interrupt
		case "clear_screen":
			cmd = tea.ClearScreen
		case "enter_alt_screen":
			cmd = tea.EnterAltScreen
		case "exit_alt_screen":
			cmd = tea.ExitAltScreen
		case "enable_mouse_cell_motion":
			cmd = tea.EnableMouseCellMotion
		case "enable_mouse_all_motion":
			cmd = tea.EnableMouseAllMotion
		case "disable_mouse":
			cmd = tea.DisableMouse
		case "hide_cursor":
			cmd = tea.HideCursor
		case "show_cursor":
			cmd = tea.ShowCursor
		case "enable_bracketed_paste":
			cmd = tea.EnableBracketedPaste
		case "disable_bracketed_paste":
			cmd = tea.DisableBracketedPaste
		case "enable_report_focus":
			cmd = tea.EnableReportFocus
		case "disable_report_focus":
			cmd = tea.DisableReportFocus
		case "window_size":
			cmd = tea.WindowSize()
		case "set_window_title":
			cmd = tea.SetWindowTitle(c.Text)
		case "println":
			cmd = tea.Println(c.Text)
		case "go":
			if gc, ok := goCmds.take(c.Handle); ok && gc != nil {
				async = append(async, gc)
			}
			continue
		}
		if cmd != nil {
			controls = append(controls, cmd)
		}
	}
	all := async
	if len(controls) > 0 {
		all = append(all, tea.Sequence(controls...))
	}
	switch len(all) {
	case 0:
		return nil
	case 1:
		return all[0]
	}
	return tea.Batch(all...)
}

// bt_program_new creates a program from JSON options and returns its handle.
//
//export bt_program_new
func bt_program_new(opts *C.char, n C.int) C.ulonglong {
	st := &program{
		opts:      programOptions{OutputFD: -1, InputFD: -1},
		done:      make(chan struct{}),
		frameWake: make(chan struct{}, 1),
	}
	if data := goBytes(opts, n); data != nil {
		if err := json.Unmarshal(data, &st.opts); err != nil {
			return 0
		}
	}
	var fds [2]int
	if err := syscall.Pipe2(fds[:], syscall.O_CLOEXEC|syscall.O_NONBLOCK); err != nil {
		return 0
	}
	st.notifyR, st.notifyW = fds[0], fds[1]
	st.id = programs.add(st)
	return C.ulonglong(st.id)
}

// bt_program_notify_fd returns the read end of the notification pipe. One
// byte becomes readable whenever messages are waiting in bt_program_poll.
//
//export bt_program_notify_fd
func bt_program_notify_fd(id C.ulonglong) C.int {
	st, ok := programs.get(uint64(id))
	if !ok {
		return -1
	}
	return C.int(st.notifyR)
}

func dupFile(fd int, name string) (*os.File, error) {
	nfd, err := syscall.Dup(fd)
	if err != nil {
		return nil, err
	}
	syscall.CloseOnExec(nfd)
	return os.NewFile(uintptr(nfd), name), nil
}

// bt_program_start runs the program in the background with the initial view
// and commands (JSON list, may be empty). Returns 0 on success.
//
//export bt_program_start
func bt_program_start(id C.ulonglong, view *C.char, viewLen C.int, cmds *C.char, cmdsLen C.int) C.int {
	st, ok := programs.get(uint64(id))
	if !ok {
		return -1
	}
	st.mu.Lock()
	if st.started {
		st.mu.Unlock()
		return -2
	}
	st.started = true
	st.mu.Unlock()

	o := st.opts
	model := &proxy{st: st, view: goString(view, viewLen), init: buildCmd(goBytes(cmds, cmdsLen))}
	var popts []tea.ProgramOption
	if o.AltScreen {
		popts = append(popts, tea.WithAltScreen())
	}
	switch o.Mouse {
	case "cell":
		popts = append(popts, tea.WithMouseCellMotion())
	case "all":
		popts = append(popts, tea.WithMouseAllMotion())
	}
	if o.ReportFocus {
		popts = append(popts, tea.WithReportFocus())
	}
	if o.BracketedPaste != nil && !*o.BracketedPaste {
		popts = append(popts, tea.WithoutBracketedPaste())
	}
	if o.FPS > 0 {
		popts = append(popts, tea.WithFPS(o.FPS))
	}
	if o.Signals != nil && !*o.Signals {
		popts = append(popts, tea.WithoutSignals())
	}
	if o.CatchPanics != nil && !*o.CatchPanics {
		popts = append(popts, tea.WithoutCatchPanics())
	}
	if o.Renderer != nil && !*o.Renderer {
		popts = append(popts, tea.WithoutRenderer())
	}
	switch o.Input {
	case "tty":
		popts = append(popts, tea.WithInputTTY())
	case "none":
		popts = append(popts, tea.WithInput(nil))
	case "fd":
		f, err := dupFile(o.InputFD, "input")
		if err != nil {
			return -3
		}
		st.files = append(st.files, f)
		popts = append(popts, tea.WithInput(f))
	}
	if o.OutputFD >= 0 {
		f, err := dupFile(o.OutputFD, "output")
		if err != nil {
			st.closeFiles()
			return -4
		}
		st.files = append(st.files, f)
		popts = append(popts, tea.WithOutput(f))
	}

	st.tp = tea.NewProgram(model, popts...)
	go st.sendLoop()
	go func() {
		_, err := st.tp.Run()
		exit := msgJSON{Type: "exit"}
		if err != nil {
			exit.Error = err.Error()
			exit.Killed = errors.Is(err, tea.ErrProgramKilled)
			exit.Interrupted = errors.Is(err, tea.ErrInterrupted)
		}
		st.mu.Lock()
		st.finished = true
		st.mu.Unlock()
		close(st.done)
		st.closeFiles()
		st.push(exit)
	}()
	return 0
}

// bt_program_poll returns all queued messages as a JSON array, or NULL.
//
//export bt_program_poll
func bt_program_poll(id C.ulonglong) *C.char {
	st, ok := programs.get(uint64(id))
	if !ok {
		return nil
	}
	// drain the notification pipe first, then take the queue: a message
	// pushed after this point writes a fresh byte.
	var buf [64]byte
	for {
		n, err := syscall.Read(st.notifyR, buf[:])
		if n <= 0 || err != nil {
			break
		}
	}
	st.mu.Lock()
	q := st.queue
	st.queue = nil
	st.notified = false
	st.mu.Unlock()
	if len(q) == 0 {
		return nil
	}
	b, _ := json.Marshal(q)
	return cString(string(b))
}

// bt_program_update sends a new view (viewLen < 0: unchanged) and a JSON
// list of commands to the running program. It never blocks.
//
//export bt_program_update
func bt_program_update(id C.ulonglong, view *C.char, viewLen C.int, cmds *C.char, cmdsLen C.int) C.int {
	st, ok := programs.get(uint64(id))
	if !ok || st.tp == nil {
		return -1
	}
	f := frameMsg{cmd: buildCmd(goBytes(cmds, cmdsLen))}
	if viewLen >= 0 {
		f.view = goString(view, viewLen)
		f.hasView = true
	}
	st.frameMu.Lock()
	st.frames = append(st.frames, f)
	st.frameMu.Unlock()
	select {
	case st.frameWake <- struct{}{}:
	default:
	}
	return 0
}

func (st *program) killAndWait(timeout time.Duration) bool {
	if st.tp == nil {
		return true
	}
	st.tp.Kill()
	select {
	case <-st.done:
		return true
	case <-time.After(timeout):
		return false
	}
}

// bt_program_kill stops the program and waits (up to 2s) until Bubble Tea
// has restored the terminal. Returns 1 if it finished in time.
//
//export bt_program_kill
func bt_program_kill(id C.ulonglong) C.int {
	st, ok := programs.get(uint64(id))
	if !ok {
		return 1
	}
	if st.killAndWait(2 * time.Second) {
		return 1
	}
	return 0
}

// bt_program_wait blocks until the program has finished (up to timeoutMs).
//
//export bt_program_wait
func bt_program_wait(id C.ulonglong, timeoutMs C.int) C.int {
	st, ok := programs.get(uint64(id))
	if !ok || st.tp == nil {
		return 1
	}
	select {
	case <-st.done:
		return 1
	case <-time.After(time.Duration(timeoutMs) * time.Millisecond):
		return 0
	}
}

// bt_program_free kills the program if needed and releases its resources.
//
//export bt_program_free
func bt_program_free(id C.ulonglong) {
	st, ok := programs.take(uint64(id))
	if !ok {
		return
	}
	st.killAndWait(2 * time.Second)
	_ = syscall.Close(st.notifyR)
	_ = syscall.Close(st.notifyW)
}

// bt_shutdown kills every running program (used from an at_exit hook).
//
//export bt_shutdown
func bt_shutdown() {
	for _, st := range programs.values() {
		st.mu.Lock()
		running := st.started && !st.finished
		st.mu.Unlock()
		if running {
			st.killAndWait(2 * time.Second)
		}
	}
}
