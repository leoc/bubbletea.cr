package main

import (
	"encoding/json"

	"github.com/charmbracelet/bubbles/textarea"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
)

func init() {
	componentFactories["textinput"] = newTextInput
	componentFactories["textarea"] = newTextArea
}

// ---------------------------------------------------------------- textinput

type textInputComponent struct{ m textinput.Model }

type textInputOptions struct {
	Prompt           *string         `json:"prompt"`
	Placeholder      *string         `json:"placeholder"`
	Value            *string         `json:"value"`
	EchoMode         string          `json:"echo_mode"` // normal, password, none
	EchoCharacter    string          `json:"echo_character"`
	CharLimit        *int            `json:"char_limit"`
	Width            *int            `json:"width"`
	ShowSuggestions  *bool           `json:"show_suggestions"`
	Suggestions      []string        `json:"suggestions"`
	PromptStyle      json.RawMessage `json:"prompt_style"`
	TextStyle        json.RawMessage `json:"text_style"`
	PlaceholderStyle json.RawMessage `json:"placeholder_style"`
	CompletionStyle  json.RawMessage `json:"completion_style"`
	CursorStyle      json.RawMessage `json:"cursor_style"`
	KeyMap           json.RawMessage `json:"key_map"`
}

func (t *textInputComponent) configure(raw json.RawMessage) error {
	var o textInputOptions
	if err := unmarshalInto(raw, &o); err != nil {
		return err
	}
	if o.Prompt != nil {
		t.m.Prompt = *o.Prompt
	}
	if o.Placeholder != nil {
		t.m.Placeholder = *o.Placeholder
	}
	switch o.EchoMode {
	case "normal":
		t.m.EchoMode = textinput.EchoNormal
	case "password":
		t.m.EchoMode = textinput.EchoPassword
	case "none":
		t.m.EchoMode = textinput.EchoNone
	case "":
	default:
		return errorf("unknown echo mode %q", o.EchoMode)
	}
	if o.EchoCharacter != "" {
		t.m.EchoCharacter = []rune(o.EchoCharacter)[0]
	}
	if o.CharLimit != nil {
		t.m.CharLimit = *o.CharLimit
	}
	if o.Width != nil {
		t.m.Width = *o.Width
	}
	if o.ShowSuggestions != nil {
		t.m.ShowSuggestions = *o.ShowSuggestions
	}
	if o.Suggestions != nil {
		t.m.SetSuggestions(o.Suggestions)
	}
	setStyle(&t.m.PromptStyle, o.PromptStyle)
	setStyle(&t.m.TextStyle, o.TextStyle)
	setStyle(&t.m.PlaceholderStyle, o.PlaceholderStyle)
	setStyle(&t.m.CompletionStyle, o.CompletionStyle)
	setStyle(&t.m.Cursor.Style, o.CursorStyle)
	if o.Value != nil {
		t.m.SetValue(*o.Value)
	}
	return applyKeyMap(&t.m.KeyMap, o.KeyMap)
}

func newTextInput(raw json.RawMessage) (component, error) {
	t := &textInputComponent{m: textinput.New()}
	return t, t.configure(raw)
}

func (t *textInputComponent) update(msg tea.Msg) tea.Cmd {
	var cmd tea.Cmd
	t.m, cmd = t.m.Update(msg)
	return cmd
}

func (t *textInputComponent) view() string { return t.m.View() }

func (t *textInputComponent) call(method string, args []json.RawMessage) (any, error) {
	switch method {
	case "configure":
		o, _ := arg[json.RawMessage](args, 0)
		return nil, t.configure(o)
	case "value":
		return t.m.Value(), nil
	case "set_value":
		s, err := arg[string](args, 0)
		t.m.SetValue(s)
		return nil, err
	case "focus":
		return t.m.Focus(), nil
	case "blur":
		t.m.Blur()
		return nil, nil
	case "focused":
		return t.m.Focused(), nil
	case "reset":
		t.m.Reset()
		return nil, nil
	case "position":
		return t.m.Position(), nil
	case "set_cursor":
		n, err := arg[int](args, 0)
		t.m.SetCursor(n)
		return nil, err
	case "cursor_start":
		t.m.CursorStart()
		return nil, nil
	case "cursor_end":
		t.m.CursorEnd()
		return nil, nil
	case "current_suggestion":
		return t.m.CurrentSuggestion(), nil
	case "matched_suggestions":
		return t.m.MatchedSuggestions(), nil
	case "key_map":
		return keyMapBindings(t.m.KeyMap), nil
	}
	return nil, errUnknownMethod
}

// ---------------------------------------------------------------- textarea

type textAreaComponent struct{ m textarea.Model }

type textAreaStyleJSON struct {
	Base             json.RawMessage `json:"base"`
	CursorLine       json.RawMessage `json:"cursor_line"`
	CursorLineNumber json.RawMessage `json:"cursor_line_number"`
	EndOfBuffer      json.RawMessage `json:"end_of_buffer"`
	LineNumber       json.RawMessage `json:"line_number"`
	Placeholder      json.RawMessage `json:"placeholder"`
	Prompt           json.RawMessage `json:"prompt"`
	Text             json.RawMessage `json:"text"`
}

func (s *textAreaStyleJSON) apply(dst *textarea.Style) {
	setStyle(&dst.Base, s.Base)
	setStyle(&dst.CursorLine, s.CursorLine)
	setStyle(&dst.CursorLineNumber, s.CursorLineNumber)
	setStyle(&dst.EndOfBuffer, s.EndOfBuffer)
	setStyle(&dst.LineNumber, s.LineNumber)
	setStyle(&dst.Placeholder, s.Placeholder)
	setStyle(&dst.Prompt, s.Prompt)
	setStyle(&dst.Text, s.Text)
}

type textAreaOptions struct {
	Prompt          *string            `json:"prompt"`
	Placeholder     *string            `json:"placeholder"`
	Value           *string            `json:"value"`
	ShowLineNumbers *bool              `json:"show_line_numbers"`
	EndOfBuffer     string             `json:"end_of_buffer_character"`
	CharLimit       *int               `json:"char_limit"`
	MaxHeight       *int               `json:"max_height"`
	MaxWidth        *int               `json:"max_width"`
	Width           *int               `json:"width"`
	Height          *int               `json:"height"`
	FocusedStyle    *textAreaStyleJSON `json:"focused_style"`
	BlurredStyle    *textAreaStyleJSON `json:"blurred_style"`
	CursorStyle     json.RawMessage    `json:"cursor_style"`
	KeyMap          json.RawMessage    `json:"key_map"`
}

func (t *textAreaComponent) configure(raw json.RawMessage) error {
	var o textAreaOptions
	if err := unmarshalInto(raw, &o); err != nil {
		return err
	}
	if o.Prompt != nil {
		t.m.Prompt = *o.Prompt
	}
	if o.Placeholder != nil {
		t.m.Placeholder = *o.Placeholder
	}
	if o.ShowLineNumbers != nil {
		t.m.ShowLineNumbers = *o.ShowLineNumbers
	}
	if o.EndOfBuffer != "" {
		t.m.EndOfBufferCharacter = []rune(o.EndOfBuffer)[0]
	}
	if o.CharLimit != nil {
		t.m.CharLimit = *o.CharLimit
	}
	if o.MaxHeight != nil {
		t.m.MaxHeight = *o.MaxHeight
	}
	if o.MaxWidth != nil {
		t.m.MaxWidth = *o.MaxWidth
	}
	if o.FocusedStyle != nil {
		o.FocusedStyle.apply(&t.m.FocusedStyle)
	}
	if o.BlurredStyle != nil {
		o.BlurredStyle.apply(&t.m.BlurredStyle)
	}
	setStyle(&t.m.Cursor.Style, o.CursorStyle)
	if o.Width != nil {
		t.m.SetWidth(*o.Width)
	}
	if o.Height != nil {
		t.m.SetHeight(*o.Height)
	}
	if o.Value != nil {
		t.m.SetValue(*o.Value)
	}
	return applyKeyMap(&t.m.KeyMap, o.KeyMap)
}

func newTextArea(raw json.RawMessage) (component, error) {
	t := &textAreaComponent{m: textarea.New()}
	return t, t.configure(raw)
}

func (t *textAreaComponent) update(msg tea.Msg) tea.Cmd {
	var cmd tea.Cmd
	t.m, cmd = t.m.Update(msg)
	return cmd
}

func (t *textAreaComponent) view() string { return t.m.View() }

func (t *textAreaComponent) call(method string, args []json.RawMessage) (any, error) {
	switch method {
	case "configure":
		o, _ := arg[json.RawMessage](args, 0)
		return nil, t.configure(o)
	case "value":
		return t.m.Value(), nil
	case "set_value":
		s, err := arg[string](args, 0)
		t.m.SetValue(s)
		return nil, err
	case "insert_string":
		s, err := arg[string](args, 0)
		t.m.InsertString(s)
		return nil, err
	case "focus":
		return t.m.Focus(), nil
	case "blur":
		t.m.Blur()
		return nil, nil
	case "focused":
		return t.m.Focused(), nil
	case "reset":
		t.m.Reset()
		return nil, nil
	case "state":
		info := t.m.LineInfo()
		return map[string]any{
			"line": t.m.Line(), "line_count": t.m.LineCount(), "length": t.m.Length(),
			"width": t.m.Width(), "height": t.m.Height(),
			"column": info.ColumnOffset, "row_offset": info.RowOffset,
		}, nil
	case "cursor_up":
		t.m.CursorUp()
	case "cursor_down":
		t.m.CursorDown()
	case "cursor_start":
		t.m.CursorStart()
	case "cursor_end":
		t.m.CursorEnd()
	case "set_cursor":
		n, err := arg[int](args, 0)
		t.m.SetCursor(n)
		return nil, err
	case "key_map":
		return keyMapBindings(t.m.KeyMap), nil
	default:
		return nil, errUnknownMethod
	}
	return nil, nil
}
