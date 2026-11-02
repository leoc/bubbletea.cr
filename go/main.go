// Package main builds libbubbletea_go, a C shared library that exposes
// Bubble Tea, Lip Gloss, Bubbles and Glamour to Crystal (see DESIGN.md).
//
// Conventions for every exported function:
//   - strings from the caller arrive as pointer + length and are copied
//     before the function returns;
//   - strings returned to the caller are allocated with C.CString and must be
//     released with bt_free;
//   - Go objects never cross the boundary; they are referenced by uint64
//     handles into registries.
package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"runtime/debug"
	"sync"
	"unsafe"
)

func main() {}

// registry maps handles to Go values of one kind.
type registry[T any] struct {
	mu    sync.Mutex
	next  uint64
	items map[uint64]T
}

func newRegistry[T any]() *registry[T] {
	return &registry[T]{items: map[uint64]T{}}
}

func (r *registry[T]) add(v T) uint64 {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.next++
	r.items[r.next] = v
	return r.next
}

func (r *registry[T]) get(id uint64) (T, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	v, ok := r.items[id]
	return v, ok
}

// take returns the value and removes it from the registry.
func (r *registry[T]) take(id uint64) (T, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	v, ok := r.items[id]
	delete(r.items, id)
	return v, ok
}

func (r *registry[T]) remove(id uint64) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.items, id)
}

func (r *registry[T]) len() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.items)
}

func (r *registry[T]) values() []T {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]T, 0, len(r.items))
	for _, v := range r.items {
		out = append(out, v)
	}
	return out
}

func goString(p *C.char, n C.int) string {
	if p == nil || n <= 0 {
		return ""
	}
	return C.GoStringN(p, n)
}

func goBytes(p *C.char, n C.int) []byte {
	if p == nil || n <= 0 {
		return nil
	}
	return C.GoBytes(unsafe.Pointer(p), n)
}

func cString(s string) *C.char {
	return C.CString(s)
}

// cJSON marshals v; marshalling errors become {"error": "..."}.
func cJSON(v any) *C.char {
	b, err := json.Marshal(v)
	if err != nil {
		b, _ = json.Marshal(map[string]string{"error": err.Error()})
	}
	return C.CString(string(b))
}

//export bt_free
func bt_free(p *C.char) {
	C.free(unsafe.Pointer(p))
}

// bt_versions returns the versions of the wrapped Go modules as JSON.
//
//export bt_versions
func bt_versions() *C.char {
	out := map[string]string{}
	if info, ok := debug.ReadBuildInfo(); ok {
		out["go"] = info.GoVersion
		for _, dep := range info.Deps {
			switch dep.Path {
			case "github.com/charmbracelet/bubbletea", "github.com/charmbracelet/lipgloss",
				"github.com/charmbracelet/bubbles", "github.com/charmbracelet/glamour":
				out[dep.Path[len("github.com/charmbracelet/"):]] = dep.Version
			}
		}
	}
	return cJSON(out)
}
