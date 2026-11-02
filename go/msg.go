package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

// Messages that have no JSON representation (component ticks, filter
// results, ...) are kept here and referenced by handle from Crystal.
var goMsgs = newRegistry[tea.Msg]()

// Commands produced by components, executed later by a program.
var goCmds = newRegistry[tea.Cmd]()

// msgJSON is the wire format for messages in both directions.
type msgJSON struct {
	Type string `json:"type"`

	// key
	Key     string `json:"key,omitempty"`
	KeyType int    `json:"key_type"`
	KeyName string `json:"key_name,omitempty"`
	Runes   string `json:"runes,omitempty"`
	Alt     bool   `json:"alt,omitempty"`
	Paste   bool   `json:"paste,omitempty"`

	// mouse
	X      int  `json:"x"`
	Y      int  `json:"y"`
	Shift  bool `json:"shift,omitempty"`
	Ctrl   bool `json:"ctrl,omitempty"`
	Action int  `json:"action"`
	Button int  `json:"button"`

	// window_size
	Width  int `json:"width"`
	Height int `json:"height"`

	// go
	Handle uint64 `json:"handle,omitempty"`
	GoType string `json:"go_type,omitempty"`

	// exit
	Error       string `json:"error,omitempty"`
	Killed      bool   `json:"killed,omitempty"`
	Interrupted bool   `json:"interrupted,omitempty"`
}

// encodeMsg converts a Bubble Tea message for Crystal. ok is false for
// Bubble Tea internals that the model never needs to see.
func encodeMsg(msg tea.Msg) (msgJSON, bool) {
	switch m := msg.(type) {
	case tea.KeyMsg:
		return msgJSON{
			Type:    "key",
			Key:     m.String(),
			KeyType: int(m.Type),
			KeyName: m.Type.String(),
			Runes:   string(m.Runes),
			Alt:     m.Alt,
			Paste:   m.Paste,
		}, true
	case tea.MouseMsg:
		return msgJSON{
			Type:   "mouse",
			Key:    m.String(),
			X:      m.X,
			Y:      m.Y,
			Shift:  m.Shift,
			Alt:    m.Alt,
			Ctrl:   m.Ctrl,
			Action: int(m.Action),
			Button: int(m.Button),
		}, true
	case tea.WindowSizeMsg:
		return msgJSON{Type: "window_size", Width: m.Width, Height: m.Height}, true
	case tea.FocusMsg:
		return msgJSON{Type: "focus"}, true
	case tea.BlurMsg:
		return msgJSON{Type: "blur"}, true
	case nil:
		return msgJSON{}, false
	}
	typ := fmt.Sprintf("%T", msg)
	if strings.HasPrefix(typ, "tea.") {
		// unexported Bubble Tea control messages (alt screen, mouse modes...)
		return msgJSON{}, false
	}
	return msgJSON{Type: "go", Handle: goMsgs.add(msg), GoType: typ}, true
}

// decodeMsg reconstructs a Bubble Tea message from its JSON form.
func decodeMsg(data []byte) (tea.Msg, error) {
	var m msgJSON
	if err := json.Unmarshal(data, &m); err != nil {
		return nil, err
	}
	switch m.Type {
	case "key":
		k := tea.Key{Type: tea.KeyType(m.KeyType), Alt: m.Alt, Paste: m.Paste}
		if m.Runes != "" {
			k.Runes = []rune(m.Runes)
		}
		return tea.KeyMsg(k), nil
	case "mouse":
		return tea.MouseMsg{
			X: m.X, Y: m.Y, Shift: m.Shift, Alt: m.Alt, Ctrl: m.Ctrl,
			Action: tea.MouseAction(m.Action), Button: tea.MouseButton(m.Button),
		}, nil
	case "window_size":
		return tea.WindowSizeMsg{Width: m.Width, Height: m.Height}, nil
	case "focus":
		return tea.FocusMsg{}, nil
	case "blur":
		return tea.BlurMsg{}, nil
	case "go":
		if msg, ok := goMsgs.get(m.Handle); ok {
			return msg, nil
		}
		return nil, nil
	}
	return nil, nil
}

// keyTypes maps key names ("enter", "ctrl+c", "up") to key types.
var keyTypes = func() map[string]tea.KeyType {
	out := map[string]tea.KeyType{}
	for i := -1000; i <= 1000; i++ {
		kt := tea.KeyType(i)
		if name := kt.String(); name != "" {
			if _, seen := out[name]; !seen {
				out[name] = kt
			}
		}
	}
	return out
}()

// parseKey turns "a", "alt+x", "ctrl+c", "enter" or "shift+tab" into a key.
func parseKey(s string) (tea.Key, bool) {
	if kt, ok := keyTypes[s]; ok && kt != tea.KeyRunes {
		return tea.Key{Type: kt}, true
	}
	if strings.HasPrefix(s, "alt+") && len(s) > 4 {
		k, ok := parseKey(s[4:])
		k.Alt = true
		return k, ok
	}
	if s == " " {
		return tea.Key{Type: tea.KeySpace, Runes: []rune(" ")}, true
	}
	if s != "" {
		return tea.Key{Type: tea.KeyRunes, Runes: []rune(s)}, true
	}
	return tea.Key{}, false
}

// bt_key_parse returns the JSON key message for a key string, or "null".
//
//export bt_key_parse
func bt_key_parse(s *C.char, n C.int) *C.char {
	k, ok := parseKey(goString(s, n))
	if !ok {
		return cString("null")
	}
	m, _ := encodeMsg(tea.KeyMsg(k))
	return cJSON(m)
}

//export bt_msg_free
func bt_msg_free(handle C.ulonglong) {
	goMsgs.remove(uint64(handle))
}

//export bt_cmd_free
func bt_cmd_free(handle C.ulonglong) {
	goCmds.remove(uint64(handle))
}

// bt_handle_counts reports registry sizes (for leak checks in specs).
//
//export bt_handle_counts
func bt_handle_counts() *C.char {
	return cJSON(map[string]int{
		"msgs":       goMsgs.len(),
		"cmds":       goCmds.len(),
		"programs":   programs.len(),
		"components": components.len(),
	})
}
