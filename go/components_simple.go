package main

import (
	"encoding/json"
	"time"

	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/paginator"
	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
)

func init() {
	componentFactories["spinner"] = newSpinner
	componentFactories["progress"] = newProgress
	componentFactories["viewport"] = newViewport
	componentFactories["paginator"] = newPaginator
	componentFactories["help"] = newHelp
}

// ---------------------------------------------------------------- spinner

type spinnerComponent struct{ m spinner.Model }

var spinners = map[string]spinner.Spinner{
	"line": spinner.Line, "dot": spinner.Dot, "mini_dot": spinner.MiniDot, "jump": spinner.Jump,
	"pulse": spinner.Pulse, "points": spinner.Points, "globe": spinner.Globe, "moon": spinner.Moon,
	"monkey": spinner.Monkey, "meter": spinner.Meter, "hamburger": spinner.Hamburger,
	"ellipsis": spinner.Ellipsis,
}

type spinnerOptions struct {
	Type   string          `json:"type"`
	Frames []string        `json:"frames"`
	FPS    float64         `json:"fps"` // frames per second
	Style  json.RawMessage `json:"style"`
}

func (s *spinnerComponent) configure(raw json.RawMessage) error {
	var o spinnerOptions
	if err := unmarshalInto(raw, &o); err != nil {
		return err
	}
	if o.Type != "" {
		sp, ok := spinners[o.Type]
		if !ok {
			return errorf("unknown spinner type %q", o.Type)
		}
		s.m.Spinner = sp
	}
	if len(o.Frames) > 0 {
		s.m.Spinner.Frames = o.Frames
		if o.FPS <= 0 {
			o.FPS = 10
		}
	}
	if o.FPS > 0 {
		s.m.Spinner.FPS = time.Duration(float64(time.Second) / o.FPS)
	}
	setStyle(&s.m.Style, o.Style)
	return nil
}

func newSpinner(raw json.RawMessage) (component, error) {
	s := &spinnerComponent{m: spinner.New()}
	return s, s.configure(raw)
}

func (s *spinnerComponent) update(msg tea.Msg) tea.Cmd {
	var cmd tea.Cmd
	s.m, cmd = s.m.Update(msg)
	return cmd
}

func (s *spinnerComponent) view() string { return s.m.View() }

func (s *spinnerComponent) call(method string, args []json.RawMessage) (any, error) {
	switch method {
	case "configure":
		o, _ := arg[json.RawMessage](args, 0)
		return nil, s.configure(o)
	case "tick":
		return tea.Cmd(s.m.Tick), nil
	case "id":
		return s.m.ID(), nil
	}
	return nil, errUnknownMethod
}

// ---------------------------------------------------------------- progress

type progressComponent struct{ m progress.Model }

type progressOptions struct {
	Width           *int            `json:"width"`
	Gradient        []string        `json:"gradient"` // two colours
	ScaledGradient  *bool           `json:"scale_gradient"`
	SolidFill       string          `json:"solid_fill"`
	Full            string          `json:"full"`
	Empty           string          `json:"empty"`
	EmptyColor      string          `json:"empty_color"`
	ShowPercentage  *bool           `json:"show_percentage"`
	PercentFormat   string          `json:"percent_format"`
	PercentageStyle json.RawMessage `json:"percentage_style"`
	Spring          []float64       `json:"spring"` // frequency, damping
}

func newProgress(raw json.RawMessage) (component, error) {
	var o progressOptions
	if err := unmarshalInto(raw, &o); err != nil {
		return nil, err
	}
	var opts []progress.Option
	switch {
	case len(o.Gradient) == 2 && o.ScaledGradient != nil && *o.ScaledGradient:
		opts = append(opts, progress.WithScaledGradient(o.Gradient[0], o.Gradient[1]))
	case len(o.Gradient) == 2:
		opts = append(opts, progress.WithGradient(o.Gradient[0], o.Gradient[1]))
	case o.SolidFill != "":
		opts = append(opts, progress.WithSolidFill(o.SolidFill))
	default:
		opts = append(opts, progress.WithDefaultGradient())
	}
	if len(o.Spring) == 2 {
		opts = append(opts, progress.WithSpringOptions(o.Spring[0], o.Spring[1]))
	}
	p := &progressComponent{m: progress.New(opts...)}
	return p, p.configure(&o)
}

func (p *progressComponent) configure(o *progressOptions) error {
	if o.Width != nil {
		p.m.Width = *o.Width
	}
	if o.Full != "" {
		p.m.Full = []rune(o.Full)[0]
	}
	if o.Empty != "" {
		p.m.Empty = []rune(o.Empty)[0]
	}
	if o.EmptyColor != "" {
		p.m.EmptyColor = o.EmptyColor
	}
	if o.ShowPercentage != nil {
		p.m.ShowPercentage = *o.ShowPercentage
	}
	if o.PercentFormat != "" {
		p.m.PercentFormat = o.PercentFormat
	}
	setStyle(&p.m.PercentageStyle, o.PercentageStyle)
	return nil
}

func (p *progressComponent) update(msg tea.Msg) tea.Cmd {
	m, cmd := p.m.Update(msg)
	p.m = m.(progress.Model)
	return cmd
}

func (p *progressComponent) view() string { return p.m.View() }

func (p *progressComponent) call(method string, args []json.RawMessage) (any, error) {
	switch method {
	case "configure":
		raw, _ := arg[json.RawMessage](args, 0)
		var o progressOptions
		if err := unmarshalInto(raw, &o); err != nil {
			return nil, err
		}
		return nil, p.configure(&o)
	case "percent":
		return p.m.Percent(), nil
	case "set_percent", "incr_percent", "decr_percent":
		v, err := arg[float64](args, 0)
		if err != nil {
			return nil, err
		}
		switch method {
		case "set_percent":
			return p.m.SetPercent(v), nil
		case "incr_percent":
			return p.m.IncrPercent(v), nil
		}
		return p.m.DecrPercent(v), nil
	case "view_as":
		v, err := arg[float64](args, 0)
		return p.m.ViewAs(v), err
	case "animating":
		return p.m.IsAnimating(), nil
	}
	return nil, errUnknownMethod
}

// ---------------------------------------------------------------- viewport

type viewportComponent struct{ m viewport.Model }

type viewportOptions struct {
	Width             *int            `json:"width"`
	Height            *int            `json:"height"`
	MouseWheelEnabled *bool           `json:"mouse_wheel_enabled"`
	MouseWheelDelta   *int            `json:"mouse_wheel_delta"`
	Style             json.RawMessage `json:"style"`
	Content           *string         `json:"content"`
	KeyMap            json.RawMessage `json:"key_map"`
	HorizontalStep    *int            `json:"horizontal_step"`
}

func (v *viewportComponent) configure(raw json.RawMessage) error {
	var o viewportOptions
	if err := unmarshalInto(raw, &o); err != nil {
		return err
	}
	if o.Width != nil {
		v.m.Width = *o.Width
	}
	if o.Height != nil {
		v.m.Height = *o.Height
	}
	if o.MouseWheelEnabled != nil {
		v.m.MouseWheelEnabled = *o.MouseWheelEnabled
	}
	if o.MouseWheelDelta != nil {
		v.m.MouseWheelDelta = *o.MouseWheelDelta
	}
	if o.HorizontalStep != nil {
		v.m.SetHorizontalStep(*o.HorizontalStep)
	}
	setStyle(&v.m.Style, o.Style)
	if o.Content != nil {
		v.m.SetContent(*o.Content)
	}
	return applyKeyMap(&v.m.KeyMap, o.KeyMap)
}

func newViewport(raw json.RawMessage) (component, error) {
	v := &viewportComponent{m: viewport.New(0, 0)}
	return v, v.configure(raw)
}

func (v *viewportComponent) update(msg tea.Msg) tea.Cmd {
	var cmd tea.Cmd
	v.m, cmd = v.m.Update(msg)
	return cmd
}

func (v *viewportComponent) view() string { return v.m.View() }

func (v *viewportComponent) call(method string, args []json.RawMessage) (any, error) {
	intArg := func() int { n, _ := arg[int](args, 0); return n }
	switch method {
	case "configure":
		o, _ := arg[json.RawMessage](args, 0)
		return nil, v.configure(o)
	case "set_content":
		s, err := arg[string](args, 0)
		v.m.SetContent(s)
		return nil, err
	case "state":
		return map[string]any{
			"width": v.m.Width, "height": v.m.Height, "y_offset": v.m.YOffset,
			"at_top": v.m.AtTop(), "at_bottom": v.m.AtBottom(), "past_bottom": v.m.PastBottom(),
			"scroll_percent": v.m.ScrollPercent(), "horizontal_scroll_percent": v.m.HorizontalScrollPercent(),
			"total_line_count": v.m.TotalLineCount(), "visible_line_count": v.m.VisibleLineCount(),
		}, nil
	case "set_y_offset":
		v.m.SetYOffset(intArg())
	case "set_x_offset":
		v.m.SetXOffset(intArg())
	case "scroll_down":
		v.m.ScrollDown(intArg())
	case "scroll_up":
		v.m.ScrollUp(intArg())
	case "scroll_left":
		v.m.ScrollLeft(intArg())
	case "scroll_right":
		v.m.ScrollRight(intArg())
	case "page_down":
		v.m.PageDown()
	case "page_up":
		v.m.PageUp()
	case "half_page_down":
		v.m.HalfPageDown()
	case "half_page_up":
		v.m.HalfPageUp()
	case "goto_top":
		v.m.GotoTop()
	case "goto_bottom":
		v.m.GotoBottom()
	case "key_map":
		return keyMapBindings(v.m.KeyMap), nil
	default:
		return nil, errUnknownMethod
	}
	return nil, nil
}

// ---------------------------------------------------------------- paginator

type paginatorComponent struct{ m paginator.Model }

type paginatorOptions struct {
	Type         string          `json:"type"` // "arabic", "dots"
	PerPage      *int            `json:"per_page"`
	TotalPages   *int            `json:"total_pages"`
	Page         *int            `json:"page"`
	ActiveDot    *string         `json:"active_dot"`
	InactiveDot  *string         `json:"inactive_dot"`
	ArabicFormat *string         `json:"arabic_format"`
	KeyMap       json.RawMessage `json:"key_map"`
}

func (p *paginatorComponent) configure(raw json.RawMessage) error {
	var o paginatorOptions
	if err := unmarshalInto(raw, &o); err != nil {
		return err
	}
	switch o.Type {
	case "arabic":
		p.m.Type = paginator.Arabic
	case "dots":
		p.m.Type = paginator.Dots
	case "":
	default:
		return errorf("unknown paginator type %q", o.Type)
	}
	if o.PerPage != nil {
		p.m.PerPage = *o.PerPage
	}
	if o.TotalPages != nil {
		p.m.TotalPages = *o.TotalPages
	}
	if o.Page != nil {
		p.m.Page = *o.Page
	}
	if o.ActiveDot != nil {
		p.m.ActiveDot = *o.ActiveDot
	}
	if o.InactiveDot != nil {
		p.m.InactiveDot = *o.InactiveDot
	}
	if o.ArabicFormat != nil {
		p.m.ArabicFormat = *o.ArabicFormat
	}
	return applyKeyMap(&p.m.KeyMap, o.KeyMap)
}

func newPaginator(raw json.RawMessage) (component, error) {
	p := &paginatorComponent{m: paginator.New()}
	return p, p.configure(raw)
}

func (p *paginatorComponent) update(msg tea.Msg) tea.Cmd {
	var cmd tea.Cmd
	p.m, cmd = p.m.Update(msg)
	return cmd
}

func (p *paginatorComponent) view() string { return p.m.View() }

func (p *paginatorComponent) call(method string, args []json.RawMessage) (any, error) {
	switch method {
	case "configure":
		o, _ := arg[json.RawMessage](args, 0)
		return nil, p.configure(o)
	case "state":
		return map[string]any{
			"page": p.m.Page, "per_page": p.m.PerPage, "total_pages": p.m.TotalPages,
			"on_first_page": p.m.OnFirstPage(), "on_last_page": p.m.OnLastPage(),
		}, nil
	case "set_total_pages":
		n, err := arg[int](args, 0)
		return p.m.SetTotalPages(n), err
	case "items_on_page":
		n, err := arg[int](args, 0)
		return p.m.ItemsOnPage(n), err
	case "slice_bounds":
		n, err := arg[int](args, 0)
		start, end := p.m.GetSliceBounds(n)
		return []int{start, end}, err
	case "next_page":
		p.m.NextPage()
		return nil, nil
	case "prev_page":
		p.m.PrevPage()
		return nil, nil
	}
	return nil, errUnknownMethod
}

// ---------------------------------------------------------------- help

type helpComponent struct{ m help.Model }

type helpOptions struct {
	Width          *int            `json:"width"`
	ShowAll        *bool           `json:"show_all"`
	ShortSeparator *string         `json:"short_separator"`
	FullSeparator  *string         `json:"full_separator"`
	Ellipsis       *string         `json:"ellipsis"`
	Styles         json.RawMessage `json:"styles"`
}

type helpStyles struct {
	Ellipsis       json.RawMessage `json:"ellipsis"`
	ShortKey       json.RawMessage `json:"short_key"`
	ShortDesc      json.RawMessage `json:"short_desc"`
	ShortSeparator json.RawMessage `json:"short_separator"`
	FullKey        json.RawMessage `json:"full_key"`
	FullDesc       json.RawMessage `json:"full_desc"`
	FullSeparator  json.RawMessage `json:"full_separator"`
}

func (h *helpComponent) configure(raw json.RawMessage) error {
	var o helpOptions
	if err := unmarshalInto(raw, &o); err != nil {
		return err
	}
	if o.Width != nil {
		h.m.Width = *o.Width
	}
	if o.ShowAll != nil {
		h.m.ShowAll = *o.ShowAll
	}
	if o.ShortSeparator != nil {
		h.m.ShortSeparator = *o.ShortSeparator
	}
	if o.FullSeparator != nil {
		h.m.FullSeparator = *o.FullSeparator
	}
	if o.Ellipsis != nil {
		h.m.Ellipsis = *o.Ellipsis
	}
	var s helpStyles
	if err := unmarshalInto(o.Styles, &s); err != nil {
		return err
	}
	setStyle(&h.m.Styles.Ellipsis, s.Ellipsis)
	setStyle(&h.m.Styles.ShortKey, s.ShortKey)
	setStyle(&h.m.Styles.ShortDesc, s.ShortDesc)
	setStyle(&h.m.Styles.ShortSeparator, s.ShortSeparator)
	setStyle(&h.m.Styles.FullKey, s.FullKey)
	setStyle(&h.m.Styles.FullDesc, s.FullDesc)
	setStyle(&h.m.Styles.FullSeparator, s.FullSeparator)
	return nil
}

func newHelp(raw json.RawMessage) (component, error) {
	h := &helpComponent{m: help.New()}
	return h, h.configure(raw)
}

func (h *helpComponent) update(msg tea.Msg) tea.Cmd { return nil }
func (h *helpComponent) view() string               { return "" }

func toBindings(bs []bindingJSON) []key.Binding {
	out := make([]key.Binding, 0, len(bs))
	for _, b := range bs {
		out = append(out, b.binding())
	}
	return out
}

func (h *helpComponent) call(method string, args []json.RawMessage) (any, error) {
	switch method {
	case "configure":
		o, _ := arg[json.RawMessage](args, 0)
		return nil, h.configure(o)
	case "short_help_view":
		bs, err := arg[[]bindingJSON](args, 0)
		return h.m.ShortHelpView(toBindings(bs)), err
	case "full_help_view":
		groups, err := arg[[][]bindingJSON](args, 0)
		out := make([][]key.Binding, 0, len(groups))
		for _, g := range groups {
			out = append(out, toBindings(g))
		}
		return h.m.FullHelpView(out), err
	}
	return nil, errUnknownMethod
}
