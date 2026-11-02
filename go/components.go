package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"strings"
	"sync"

	"github.com/charmbracelet/bubbles/key"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// component is a Bubbles model behind a handle.
type component interface {
	update(msg tea.Msg) tea.Cmd
	view() string
	// call runs a method; args is a JSON array (may be empty).
	call(method string, args []json.RawMessage) (any, error)
}

type componentEntry struct {
	mu sync.Mutex
	c  component
}

var components = newRegistry[*componentEntry]()

var componentFactories = map[string]func(opts json.RawMessage) (component, error){}

var errUnknownMethod = errors.New("unknown method")

// ---------------------------------------------------------------- helpers

func arg[T any](args []json.RawMessage, i int) (T, error) {
	var v T
	if i >= len(args) {
		return v, fmt.Errorf("missing argument %d", i+1)
	}
	if err := json.Unmarshal(args[i], &v); err != nil {
		return v, fmt.Errorf("argument %d: %w", i+1, err)
	}
	return v, nil
}

// unmarshalInto decodes a JSON object into a struct of optional fields.
func unmarshalInto(raw json.RawMessage, v any) error {
	if len(raw) == 0 || string(raw) == "null" {
		return nil
	}
	return json.Unmarshal(raw, v)
}

// setStyle assigns a style given as JSON if present.
func setStyle(dst *lipgloss.Style, raw json.RawMessage) {
	if len(raw) > 0 && string(raw) != "null" {
		*dst = styleFromRaw(raw)
	}
}

// bindingJSON is a key binding in its JSON form.
type bindingJSON struct {
	Keys     []string `json:"keys"`
	HelpKey  string   `json:"help_key"`
	HelpDesc string   `json:"help_desc"`
	Disabled bool     `json:"disabled,omitempty"`
}

func (b bindingJSON) binding() key.Binding {
	kb := key.NewBinding(key.WithKeys(b.Keys...), key.WithHelp(b.HelpKey, b.HelpDesc))
	if b.Disabled {
		kb.SetEnabled(false)
	}
	return kb
}

func encodeBinding(b key.Binding) bindingJSON {
	h := b.Help()
	return bindingJSON{Keys: b.Keys(), HelpKey: h.Key, HelpDesc: h.Desc, Disabled: !b.Enabled()}
}

func encodeBindings(bs []key.Binding) []bindingJSON {
	out := make([]bindingJSON, 0, len(bs))
	for _, b := range bs {
		out = append(out, encodeBinding(b))
	}
	return out
}

func encodeBindingGroups(groups [][]key.Binding) [][]bindingJSON {
	out := make([][]bindingJSON, 0, len(groups))
	for _, g := range groups {
		out = append(out, encodeBindings(g))
	}
	return out
}

// normalizeName turns "cursor_up" and "CursorUp" into "cursorup".
func normalizeName(s string) string {
	return strings.ToLower(strings.ReplaceAll(s, "_", ""))
}

// applyKeyMap overrides key.Binding fields of a KeyMap struct by name:
// {"cursor_up": {"keys": ["k"], "help_key": "k", "help_desc": "up"}}.
func applyKeyMap(km any, raw json.RawMessage) error {
	var m map[string]bindingJSON
	if err := unmarshalInto(raw, &m); err != nil {
		return err
	}
	v := reflect.ValueOf(km).Elem()
	t := v.Type()
	for name, b := range m {
		found := false
		for i := 0; i < t.NumField(); i++ {
			f := t.Field(i)
			if f.Type == reflect.TypeOf(key.Binding{}) && normalizeName(f.Name) == normalizeName(name) {
				v.Field(i).Set(reflect.ValueOf(b.binding()))
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("unknown key binding %q", name)
		}
	}
	return nil
}

// keyMapBindings lists all bindings of a KeyMap struct by snake_case name.
func keyMapBindings(km any) map[string]bindingJSON {
	out := map[string]bindingJSON{}
	v := reflect.ValueOf(km)
	t := v.Type()
	for i := 0; i < t.NumField(); i++ {
		f := t.Field(i)
		if f.Type == reflect.TypeOf(key.Binding{}) {
			out[snake(f.Name)] = encodeBinding(v.Field(i).Interface().(key.Binding))
		}
	}
	return out
}

func snake(s string) string {
	var b strings.Builder
	for i, r := range s {
		if r >= 'A' && r <= 'Z' {
			if i > 0 {
				b.WriteByte('_')
			}
			b.WriteRune(r + 'a' - 'A')
		} else {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// ---------------------------------------------------------------- exports

type resultJSON struct {
	Handle uint64 `json:"handle,omitempty"`
	Result any    `json:"result"`
	Cmd    uint64 `json:"cmd,omitempty"`
	Error  string `json:"error,omitempty"`
}

func storeCmd(cmd tea.Cmd) uint64 {
	if cmd == nil {
		return 0
	}
	return goCmds.add(cmd)
}

// bt_component_new creates a component ("textinput", "list", ...) from JSON
// options. Returns {"handle": n} or {"error": "..."}.
//
//export bt_component_new
func bt_component_new(kind *C.char, kindLen C.int, opts *C.char, optsLen C.int) *C.char {
	k := goString(kind, kindLen)
	factory, ok := componentFactories[k]
	if !ok {
		return cJSON(resultJSON{Error: "unknown component " + k})
	}
	c, err := factory(goBytes(opts, optsLen))
	if err != nil {
		return cJSON(resultJSON{Error: err.Error()})
	}
	return cJSON(resultJSON{Handle: components.add(&componentEntry{c: c})})
}

// bt_component_update passes a JSON message to the component and returns a
// command handle (0: none).
//
//export bt_component_update
func bt_component_update(id C.ulonglong, msg *C.char, msgLen C.int) C.ulonglong {
	e, ok := components.get(uint64(id))
	if !ok {
		return 0
	}
	m, err := decodeMsg(goBytes(msg, msgLen))
	if err != nil || m == nil {
		return 0
	}
	e.mu.Lock()
	cmd := e.c.update(m)
	e.mu.Unlock()
	return C.ulonglong(storeCmd(cmd))
}

//export bt_component_view
func bt_component_view(id C.ulonglong) *C.char {
	e, ok := components.get(uint64(id))
	if !ok {
		return cString("")
	}
	e.mu.Lock()
	defer e.mu.Unlock()
	return cString(e.c.view())
}

// bt_component_call runs a method with JSON array arguments. Returns
// {"result": ..., "cmd": n} or {"error": "..."}. Methods that produce a
// command return it as a handle in "cmd".
//
//export bt_component_call
func bt_component_call(id C.ulonglong, method *C.char, methodLen C.int, args *C.char, argsLen C.int) *C.char {
	e, ok := components.get(uint64(id))
	if !ok {
		return cJSON(resultJSON{Error: "component freed"})
	}
	var list []json.RawMessage
	if data := goBytes(args, argsLen); len(data) > 0 {
		if err := json.Unmarshal(data, &list); err != nil {
			return cJSON(resultJSON{Error: "arguments: " + err.Error()})
		}
	}
	name := goString(method, methodLen)
	e.mu.Lock()
	res, err := e.c.call(name, list)
	e.mu.Unlock()
	if err != nil {
		if errors.Is(err, errUnknownMethod) {
			err = fmt.Errorf("%T has no method %q", e.c, name)
		}
		return cJSON(resultJSON{Error: err.Error()})
	}
	if cmd, ok := res.(tea.Cmd); ok {
		return cJSON(resultJSON{Cmd: storeCmd(cmd)})
	}
	if wc, ok := res.(withCmd); ok {
		return cJSON(resultJSON{Result: wc.result, Cmd: storeCmd(wc.cmd)})
	}
	return cJSON(resultJSON{Result: res})
}

// withCmd returns a result and a command from call.
type withCmd struct {
	result any
	cmd    tea.Cmd
}

//export bt_component_free
func bt_component_free(id C.ulonglong) {
	components.remove(uint64(id))
}

func errorf(format string, args ...any) error { return fmt.Errorf(format, args...) }
