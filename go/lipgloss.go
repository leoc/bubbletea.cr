package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"strings"
	"sync"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/lipgloss/table"
	"github.com/muesli/termenv"
)

// ---------------------------------------------------------------- colours

type completeColorJSON struct {
	TrueColor string `json:"true_color"`
	ANSI256   string `json:"ansi256"`
	ANSI      string `json:"ansi"`
}

// parseColor accepts "#ff00ff" / "201" / "" (no colour), {"light","dark"}
// (adaptive), {"true_color","ansi256","ansi"} (complete) and
// {"light":{complete},"dark":{complete}} (complete adaptive).
func parseColor(raw json.RawMessage) (lipgloss.TerminalColor, bool) {
	if len(raw) == 0 || string(raw) == "null" {
		return nil, false
	}
	var s string
	if json.Unmarshal(raw, &s) == nil {
		if s == "" {
			return lipgloss.NoColor{}, true
		}
		return lipgloss.Color(s), true
	}
	var obj map[string]json.RawMessage
	if json.Unmarshal(raw, &obj) != nil {
		return nil, false
	}
	if _, ok := obj["true_color"]; ok {
		var c completeColorJSON
		_ = json.Unmarshal(raw, &c)
		return lipgloss.CompleteColor{TrueColor: c.TrueColor, ANSI256: c.ANSI256, ANSI: c.ANSI}, true
	}
	light, dark := obj["light"], obj["dark"]
	var ls, ds string
	if json.Unmarshal(light, &ls) == nil && json.Unmarshal(dark, &ds) == nil {
		return lipgloss.AdaptiveColor{Light: ls, Dark: ds}, true
	}
	var lc, dc completeColorJSON
	_ = json.Unmarshal(light, &lc)
	_ = json.Unmarshal(dark, &dc)
	return lipgloss.CompleteAdaptiveColor{
		Light: lipgloss.CompleteColor{TrueColor: lc.TrueColor, ANSI256: lc.ANSI256, ANSI: lc.ANSI},
		Dark:  lipgloss.CompleteColor{TrueColor: dc.TrueColor, ANSI256: dc.ANSI256, ANSI: dc.ANSI},
	}, true
}

// ---------------------------------------------------------------- borders

type borderJSON struct {
	Type       string           `json:"type"`
	Chars      *lipgloss.Border `json:"chars"`
	Sides      []bool           `json:"sides"` // top, right, bottom, left
	Foreground json.RawMessage  `json:"foreground"`
	Background json.RawMessage  `json:"background"`
}

func borderByName(name string) lipgloss.Border {
	switch name {
	case "rounded":
		return lipgloss.RoundedBorder()
	case "thick":
		return lipgloss.ThickBorder()
	case "double":
		return lipgloss.DoubleBorder()
	case "hidden":
		return lipgloss.HiddenBorder()
	case "block":
		return lipgloss.BlockBorder()
	case "outer_half_block":
		return lipgloss.OuterHalfBlockBorder()
	case "inner_half_block":
		return lipgloss.InnerHalfBlockBorder()
	case "markdown":
		return lipgloss.MarkdownBorder()
	case "ascii":
		return lipgloss.ASCIIBorder()
	}
	return lipgloss.NormalBorder()
}

func (b *borderJSON) border() lipgloss.Border {
	if b.Chars != nil {
		return *b.Chars
	}
	return borderByName(b.Type)
}

// ---------------------------------------------------------------- styles

type styleJSON struct {
	Bold                *bool           `json:"bold"`
	Italic              *bool           `json:"italic"`
	Underline           *bool           `json:"underline"`
	Strikethrough       *bool           `json:"strikethrough"`
	Reverse             *bool           `json:"reverse"`
	Blink               *bool           `json:"blink"`
	Faint               *bool           `json:"faint"`
	Foreground          json.RawMessage `json:"foreground"`
	Background          json.RawMessage `json:"background"`
	Width               *int            `json:"width"`
	Height              *int            `json:"height"`
	MaxWidth            *int            `json:"max_width"`
	MaxHeight           *int            `json:"max_height"`
	Align               *float64        `json:"align"`
	AlignVertical       *float64        `json:"align_vertical"`
	Padding             []int           `json:"padding"`
	Margin              []int           `json:"margin"`
	MarginBackground    json.RawMessage `json:"margin_background"`
	Border              *borderJSON     `json:"border"`
	Inline              *bool           `json:"inline"`
	TabWidth            *int            `json:"tab_width"`
	UnderlineSpaces     *bool           `json:"underline_spaces"`
	StrikethroughSpaces *bool           `json:"strikethrough_spaces"`
	ColorWhitespace     *bool           `json:"color_whitespace"`
	Transform           string          `json:"transform"`
	Value               *string         `json:"value"`
}

func four(v []int) (int, int, int, int) {
	switch len(v) {
	case 1:
		return v[0], v[0], v[0], v[0]
	case 2:
		return v[0], v[1], v[0], v[1]
	case 3:
		return v[0], v[1], v[2], v[1]
	case 4:
		return v[0], v[1], v[2], v[3]
	}
	return 0, 0, 0, 0
}

func buildStyle(j *styleJSON) lipgloss.Style {
	s := lipgloss.NewStyle()
	if j.Bold != nil {
		s = s.Bold(*j.Bold)
	}
	if j.Italic != nil {
		s = s.Italic(*j.Italic)
	}
	if j.Underline != nil {
		s = s.Underline(*j.Underline)
	}
	if j.Strikethrough != nil {
		s = s.Strikethrough(*j.Strikethrough)
	}
	if j.Reverse != nil {
		s = s.Reverse(*j.Reverse)
	}
	if j.Blink != nil {
		s = s.Blink(*j.Blink)
	}
	if j.Faint != nil {
		s = s.Faint(*j.Faint)
	}
	if c, ok := parseColor(j.Foreground); ok {
		s = s.Foreground(c)
	}
	if c, ok := parseColor(j.Background); ok {
		s = s.Background(c)
	}
	if j.Width != nil {
		s = s.Width(*j.Width)
	}
	if j.Height != nil {
		s = s.Height(*j.Height)
	}
	if j.MaxWidth != nil {
		s = s.MaxWidth(*j.MaxWidth)
	}
	if j.MaxHeight != nil {
		s = s.MaxHeight(*j.MaxHeight)
	}
	if j.Align != nil {
		s = s.Align(lipgloss.Position(*j.Align))
	}
	if j.AlignVertical != nil {
		s = s.AlignVertical(lipgloss.Position(*j.AlignVertical))
	}
	if len(j.Padding) > 0 {
		s = s.Padding(four(j.Padding))
	}
	if len(j.Margin) > 0 {
		s = s.Margin(four(j.Margin))
	}
	if c, ok := parseColor(j.MarginBackground); ok {
		s = s.MarginBackground(c)
	}
	if b := j.Border; b != nil {
		if len(b.Sides) > 0 {
			s = s.Border(b.border(), b.Sides...)
		} else {
			s = s.Border(b.border())
		}
		if c, ok := parseColor(b.Foreground); ok {
			s = s.BorderForeground(c)
		}
		if c, ok := parseColor(b.Background); ok {
			s = s.BorderBackground(c)
		}
	}
	if j.Inline != nil {
		s = s.Inline(*j.Inline)
	}
	if j.TabWidth != nil {
		s = s.TabWidth(*j.TabWidth)
	}
	if j.UnderlineSpaces != nil {
		s = s.UnderlineSpaces(*j.UnderlineSpaces)
	}
	if j.StrikethroughSpaces != nil {
		s = s.StrikethroughSpaces(*j.StrikethroughSpaces)
	}
	if j.ColorWhitespace != nil {
		s = s.ColorWhitespace(*j.ColorWhitespace)
	}
	switch j.Transform {
	case "upper":
		s = s.Transform(strings.ToUpper)
	case "lower":
		s = s.Transform(strings.ToLower)
	}
	if j.Value != nil {
		s = s.SetString(*j.Value)
	}
	return s
}

var (
	styleCacheMu sync.Mutex
	styleCache   = map[string]lipgloss.Style{}
)

// styleFromJSON builds (and caches) a style from its JSON description.
func styleFromJSON(data []byte) (lipgloss.Style, error) {
	key := string(data)
	styleCacheMu.Lock()
	if s, ok := styleCache[key]; ok {
		styleCacheMu.Unlock()
		return s, nil
	}
	styleCacheMu.Unlock()
	var j styleJSON
	if len(data) > 0 {
		if err := json.Unmarshal(data, &j); err != nil {
			return lipgloss.NewStyle(), err
		}
	}
	s := buildStyle(&j)
	styleCacheMu.Lock()
	if len(styleCache) > 4096 {
		styleCache = map[string]lipgloss.Style{}
	}
	styleCache[key] = s
	styleCacheMu.Unlock()
	return s, nil
}

func styleFromRaw(raw json.RawMessage) lipgloss.Style {
	if len(raw) == 0 || string(raw) == "null" {
		return lipgloss.NewStyle()
	}
	s, _ := styleFromJSON(raw)
	return s
}

// bt_style_render renders text with a style given as JSON (textLen < 0:
// render the stored string only, like Style.String).
//
//export bt_style_render
func bt_style_render(style *C.char, styleLen C.int, text *C.char, textLen C.int) *C.char {
	s, _ := styleFromJSON(goBytes(style, styleLen))
	if textLen < 0 { // no argument: render the stored string (SetString)
		return cString(s.String())
	}
	return cString(s.Render(goString(text, textLen)))
}

// bt_style_frame_size returns {"horizontal":n,"vertical":n} (border + margin + padding).
//
//export bt_style_frame_size
func bt_style_frame_size(style *C.char, styleLen C.int) *C.char {
	s, _ := styleFromJSON(goBytes(style, styleLen))
	return cJSON(map[string]int{
		"horizontal": s.GetHorizontalFrameSize(),
		"vertical":   s.GetVerticalFrameSize(),
	})
}

// ---------------------------------------------------------------- renderer

//export bt_lipgloss_set_color_profile
func bt_lipgloss_set_color_profile(p C.int) {
	lipgloss.SetColorProfile(termenv.Profile(p))
	resetStyleCache()
}

//export bt_lipgloss_color_profile
func bt_lipgloss_color_profile() C.int {
	return C.int(lipgloss.ColorProfile())
}

//export bt_lipgloss_set_dark_background
func bt_lipgloss_set_dark_background(dark C.int) {
	lipgloss.SetHasDarkBackground(dark != 0)
	resetStyleCache()
}

//export bt_lipgloss_has_dark_background
func bt_lipgloss_has_dark_background() C.int {
	if lipgloss.HasDarkBackground() {
		return 1
	}
	return 0
}

func resetStyleCache() {
	styleCacheMu.Lock()
	styleCache = map[string]lipgloss.Style{}
	styleCacheMu.Unlock()
}

// ---------------------------------------------------------------- layout

type layoutJSON struct {
	Op      string          `json:"op"` // join_horizontal, join_vertical, place, place_horizontal, place_vertical
	Pos     float64         `json:"pos"`
	VPos    float64         `json:"vpos"`
	Width   int             `json:"width"`
	Height  int             `json:"height"`
	Strs    []string        `json:"strs"`
	Str     string          `json:"str"`
	WSChars string          `json:"whitespace_chars"`
	WSFg    json.RawMessage `json:"whitespace_foreground"`
	WSBg    json.RawMessage `json:"whitespace_background"`
}

// bt_lipgloss_layout runs one layout operation described as JSON.
//
//export bt_lipgloss_layout
func bt_lipgloss_layout(spec *C.char, n C.int) *C.char {
	var j layoutJSON
	if err := json.Unmarshal(goBytes(spec, n), &j); err != nil {
		return cString("")
	}
	var ws []lipgloss.WhitespaceOption
	if j.WSChars != "" {
		ws = append(ws, lipgloss.WithWhitespaceChars(j.WSChars))
	}
	if c, ok := parseColor(j.WSFg); ok {
		ws = append(ws, lipgloss.WithWhitespaceForeground(c))
	}
	if c, ok := parseColor(j.WSBg); ok {
		ws = append(ws, lipgloss.WithWhitespaceBackground(c))
	}
	var out string
	switch j.Op {
	case "join_horizontal":
		out = lipgloss.JoinHorizontal(lipgloss.Position(j.Pos), j.Strs...)
	case "join_vertical":
		out = lipgloss.JoinVertical(lipgloss.Position(j.Pos), j.Strs...)
	case "place":
		out = lipgloss.Place(j.Width, j.Height, lipgloss.Position(j.Pos), lipgloss.Position(j.VPos), j.Str, ws...)
	case "place_horizontal":
		out = lipgloss.PlaceHorizontal(j.Width, lipgloss.Position(j.Pos), j.Str, ws...)
	case "place_vertical":
		out = lipgloss.PlaceVertical(j.Height, lipgloss.Position(j.Pos), j.Str, ws...)
	}
	return cString(out)
}

// bt_lipgloss_size returns {"width":w,"height":h} of a rendered block.
//
//export bt_lipgloss_size
func bt_lipgloss_size(s *C.char, n C.int) *C.char {
	w, h := lipgloss.Size(goString(s, n))
	return cJSON(map[string]int{"width": w, "height": h})
}

// ---------------------------------------------------------------- table

type tableJSON struct {
	Headers      []string          `json:"headers"`
	Rows         [][]string        `json:"rows"`
	Border       *borderJSON       `json:"border"`
	BorderStyle  json.RawMessage   `json:"border_style"`
	BorderTop    *bool             `json:"border_top"`
	BorderBottom *bool             `json:"border_bottom"`
	BorderLeft   *bool             `json:"border_left"`
	BorderRight  *bool             `json:"border_right"`
	BorderHeader *bool             `json:"border_header"`
	BorderColumn *bool             `json:"border_column"`
	BorderRow    *bool             `json:"border_row"`
	Width        int               `json:"width"`
	Height       int               `json:"height"`
	Offset       int               `json:"offset"`
	Wrap         *bool             `json:"wrap"`
	Styles       []json.RawMessage `json:"styles"`
	// CellStyles[row+1][col] indexes Styles (-1: none); row 0 is the header.
	CellStyles [][]int `json:"cell_styles"`
}

// bt_lipgloss_table renders a lipgloss/table described as JSON.
//
//export bt_lipgloss_table
func bt_lipgloss_table(spec *C.char, n C.int) *C.char {
	var j tableJSON
	if err := json.Unmarshal(goBytes(spec, n), &j); err != nil {
		return cString("")
	}
	t := table.New().Headers(j.Headers...).Rows(j.Rows...)
	if j.Border != nil {
		t = t.Border(j.Border.border())
	}
	if len(j.BorderStyle) > 0 {
		t = t.BorderStyle(styleFromRaw(j.BorderStyle))
	}
	set := func(v *bool, f func(bool) *table.Table) {
		if v != nil {
			t = f(*v)
		}
	}
	set(j.BorderTop, t.BorderTop)
	set(j.BorderBottom, t.BorderBottom)
	set(j.BorderLeft, t.BorderLeft)
	set(j.BorderRight, t.BorderRight)
	set(j.BorderHeader, t.BorderHeader)
	set(j.BorderColumn, t.BorderColumn)
	set(j.BorderRow, t.BorderRow)
	if j.Width > 0 {
		t = t.Width(j.Width)
	}
	if j.Height > 0 {
		t = t.Height(j.Height)
	}
	if j.Offset > 0 {
		t = t.Offset(j.Offset)
	}
	if j.Wrap != nil {
		t = t.Wrap(*j.Wrap)
	}
	if len(j.CellStyles) > 0 {
		styles := make([]lipgloss.Style, len(j.Styles))
		for i, raw := range j.Styles {
			styles[i] = styleFromRaw(raw)
		}
		cells := j.CellStyles
		t = t.StyleFunc(func(row, col int) lipgloss.Style {
			r := row + 1
			if r >= 0 && r < len(cells) && col >= 0 && col < len(cells[r]) {
				if idx := cells[r][col]; idx >= 0 && idx < len(styles) {
					return styles[idx]
				}
			}
			return lipgloss.NewStyle()
		})
	}
	return cString(t.Render())
}
