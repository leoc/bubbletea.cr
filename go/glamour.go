package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"os"

	"github.com/charmbracelet/glamour"
	"github.com/charmbracelet/glamour/styles"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/term"
)

type glamourOptions struct {
	Style            string          `json:"style"` // "auto", "dark", "light", "notty", "ascii", "dracula", "pink", "tokyo-night"
	StyleJSON        json.RawMessage `json:"style_json"`
	WordWrap         *int            `json:"word_wrap"`
	Emoji            bool            `json:"emoji"`
	PreserveNewLines bool            `json:"preserve_new_lines"`
	BaseURL          string          `json:"base_url"`
	TableWrap        *bool           `json:"table_wrap"`
	InlineTableLinks bool            `json:"inline_table_links"`
}

// bt_glamour_render renders markdown with JSON options. Returns
// {"result": "..."} or {"error": "..."}.
//
//export bt_glamour_render
func bt_glamour_render(md *C.char, mdLen C.int, opts *C.char, optsLen C.int) *C.char {
	var o glamourOptions
	if err := unmarshalInto(goBytes(opts, optsLen), &o); err != nil {
		return cJSON(resultJSON{Error: err.Error()})
	}
	var ropts []glamour.TermRendererOption
	switch {
	case len(o.StyleJSON) > 0 && string(o.StyleJSON) != "null":
		ropts = append(ropts, glamour.WithStylesFromJSONBytes(o.StyleJSON))
	case o.Style == "" || o.Style == "auto":
		// Like glamour.WithAutoStyle, but uses Lip Gloss' cached background
		// detection: querying the terminal again while a program owns stdin
		// would block until the query times out.
		switch {
		case !term.IsTerminal(os.Stdout.Fd()):
			ropts = append(ropts, glamour.WithStandardStyle(styles.NoTTYStyle))
		case lipgloss.HasDarkBackground():
			ropts = append(ropts, glamour.WithStandardStyle(styles.DarkStyle))
		default:
			ropts = append(ropts, glamour.WithStandardStyle(styles.LightStyle))
		}
	default:
		ropts = append(ropts, glamour.WithStandardStyle(o.Style))
	}
	if o.WordWrap != nil {
		ropts = append(ropts, glamour.WithWordWrap(*o.WordWrap))
	}
	if o.Emoji {
		ropts = append(ropts, glamour.WithEmoji())
	}
	if o.PreserveNewLines {
		ropts = append(ropts, glamour.WithPreservedNewLines())
	}
	if o.BaseURL != "" {
		ropts = append(ropts, glamour.WithBaseURL(o.BaseURL))
	}
	if o.TableWrap != nil {
		ropts = append(ropts, glamour.WithTableWrap(*o.TableWrap))
	}
	if o.InlineTableLinks {
		ropts = append(ropts, glamour.WithInlineTableLinks(true))
	}
	r, err := glamour.NewTermRenderer(ropts...)
	if err != nil {
		return cJSON(resultJSON{Error: err.Error()})
	}
	out, err := r.Render(goString(md, mdLen))
	if err != nil {
		return cJSON(resultJSON{Error: err.Error()})
	}
	return cJSON(resultJSON{Result: out})
}
