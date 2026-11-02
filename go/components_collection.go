package main

import (
	"encoding/json"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/table"
	tea "github.com/charmbracelet/bubbletea"
)

func init() {
	componentFactories["table"] = newTable
	componentFactories["list"] = newList
}

// ---------------------------------------------------------------- table

type tableComponent struct{ m table.Model }

type tableOptions struct {
	Columns  []table.Column   `json:"columns"`
	Rows     [][]string       `json:"rows"`
	Width    *int             `json:"width"`
	Height   *int             `json:"height"`
	Focused  *bool            `json:"focused"`
	Cursor   *int             `json:"cursor"`
	Styles   *tableStylesJSON `json:"styles"`
	KeyMap   json.RawMessage  `json:"key_map"`
	HelpKeys *bool            `json:"-"`
}

type tableStylesJSON struct {
	Header   json.RawMessage `json:"header"`
	Cell     json.RawMessage `json:"cell"`
	Selected json.RawMessage `json:"selected"`
}

func (t *tableComponent) configure(raw json.RawMessage) error {
	var o tableOptions
	if err := unmarshalInto(raw, &o); err != nil {
		return err
	}
	if o.Styles != nil {
		s := table.DefaultStyles()
		setStyle(&s.Header, o.Styles.Header)
		setStyle(&s.Cell, o.Styles.Cell)
		setStyle(&s.Selected, o.Styles.Selected)
		t.m.SetStyles(s)
	}
	if o.Columns != nil {
		t.m.SetColumns(o.Columns)
	}
	if o.Rows != nil {
		rows := make([]table.Row, len(o.Rows))
		for i, r := range o.Rows {
			rows[i] = r
		}
		t.m.SetRows(rows)
	}
	if o.Width != nil {
		t.m.SetWidth(*o.Width)
	}
	if o.Height != nil {
		t.m.SetHeight(*o.Height)
	}
	if o.Focused != nil {
		if *o.Focused {
			t.m.Focus()
		} else {
			t.m.Blur()
		}
	}
	if o.Cursor != nil {
		t.m.SetCursor(*o.Cursor)
	}
	return applyKeyMap(&t.m.KeyMap, o.KeyMap)
}

func newTable(raw json.RawMessage) (component, error) {
	t := &tableComponent{m: table.New()}
	return t, t.configure(raw)
}

func (t *tableComponent) update(msg tea.Msg) tea.Cmd {
	var cmd tea.Cmd
	t.m, cmd = t.m.Update(msg)
	return cmd
}

func (t *tableComponent) view() string { return t.m.View() }

func (t *tableComponent) call(method string, args []json.RawMessage) (any, error) {
	intArg := func() int { n, _ := arg[int](args, 0); return n }
	switch method {
	case "configure":
		o, _ := arg[json.RawMessage](args, 0)
		return nil, t.configure(o)
	case "cursor":
		return t.m.Cursor(), nil
	case "selected_row":
		return t.m.SelectedRow(), nil
	case "rows":
		return t.m.Rows(), nil
	case "focused":
		return t.m.Focused(), nil
	case "focus":
		t.m.Focus()
	case "blur":
		t.m.Blur()
	case "move_up":
		t.m.MoveUp(intArg())
	case "move_down":
		t.m.MoveDown(intArg())
	case "goto_top":
		t.m.GotoTop()
	case "goto_bottom":
		t.m.GotoBottom()
	case "help_view":
		return t.m.HelpView(), nil
	case "help_bindings":
		return map[string]any{
			"short": encodeBindings(t.m.KeyMap.ShortHelp()),
			"full":  encodeBindingGroups(t.m.KeyMap.FullHelp()),
		}, nil
	case "key_map":
		return keyMapBindings(t.m.KeyMap), nil
	default:
		return nil, errUnknownMethod
	}
	return nil, nil
}

// ---------------------------------------------------------------- list

// listItem is a list entry; ID refers to the Crystal-side item.
type listItem struct {
	ID     uint64 `json:"id"`
	T      string `json:"title"`
	D      string `json:"description"`
	Filter string `json:"filter_value"`
}

func (i listItem) Title() string       { return i.T }
func (i listItem) Description() string { return i.D }
func (i listItem) FilterValue() string {
	if i.Filter != "" {
		return i.Filter
	}
	return i.T
}

type listComponent struct {
	m        list.Model
	delegate list.DefaultDelegate
}

type listOptions struct {
	Title               *string         `json:"title"`
	Items               []listItem      `json:"items"`
	Width               *int            `json:"width"`
	Height              *int            `json:"height"`
	ShowTitle           *bool           `json:"show_title"`
	ShowFilter          *bool           `json:"show_filter"`
	ShowStatusBar       *bool           `json:"show_status_bar"`
	ShowPagination      *bool           `json:"show_pagination"`
	ShowHelp            *bool           `json:"show_help"`
	FilteringEnabled    *bool           `json:"filtering_enabled"`
	InfiniteScrolling   *bool           `json:"infinite_scrolling"`
	StatusBarItemName   []string        `json:"status_bar_item_name"`
	DisableQuitKeys     bool            `json:"disable_quit_keybindings"`
	ShowDescription     *bool           `json:"show_description"`
	ItemHeight          *int            `json:"item_height"`
	ItemSpacing         *int            `json:"item_spacing"`
	Styles              json.RawMessage `json:"styles"`
	ItemStyles          json.RawMessage `json:"item_styles"`
	KeyMap              json.RawMessage `json:"key_map"`
	SpinnerType         string          `json:"spinner"`
	AdditionalShortHelp []bindingJSON   `json:"additional_short_help"`
	AdditionalFullHelp  []bindingJSON   `json:"additional_full_help"`
}

type listStylesJSON struct {
	TitleBar              json.RawMessage `json:"title_bar"`
	Title                 json.RawMessage `json:"title"`
	Spinner               json.RawMessage `json:"spinner"`
	FilterPrompt          json.RawMessage `json:"filter_prompt"`
	FilterCursor          json.RawMessage `json:"filter_cursor"`
	DefaultFilterMatch    json.RawMessage `json:"default_filter_character_match"`
	StatusBar             json.RawMessage `json:"status_bar"`
	StatusEmpty           json.RawMessage `json:"status_empty"`
	StatusBarActiveFilter json.RawMessage `json:"status_bar_active_filter"`
	StatusBarFilterCount  json.RawMessage `json:"status_bar_filter_count"`
	NoItems               json.RawMessage `json:"no_items"`
	PaginationStyle       json.RawMessage `json:"pagination"`
	HelpStyle             json.RawMessage `json:"help"`
	ActivePaginationDot   json.RawMessage `json:"active_pagination_dot"`
	InactivePaginationDot json.RawMessage `json:"inactive_pagination_dot"`
	ArabicPagination      json.RawMessage `json:"arabic_pagination"`
	DividerDot            json.RawMessage `json:"divider_dot"`
}

type listItemStylesJSON struct {
	NormalTitle   json.RawMessage `json:"normal_title"`
	NormalDesc    json.RawMessage `json:"normal_desc"`
	SelectedTitle json.RawMessage `json:"selected_title"`
	SelectedDesc  json.RawMessage `json:"selected_desc"`
	DimmedTitle   json.RawMessage `json:"dimmed_title"`
	DimmedDesc    json.RawMessage `json:"dimmed_desc"`
	FilterMatch   json.RawMessage `json:"filter_match"`
}

func toItems(in []listItem) []list.Item {
	out := make([]list.Item, len(in))
	for i, it := range in {
		out[i] = it
	}
	return out
}

func itemIDs(in []list.Item) []uint64 {
	out := make([]uint64, len(in))
	for i, it := range in {
		out[i] = it.(listItem).ID
	}
	return out
}

func (l *listComponent) configure(raw json.RawMessage) (tea.Cmd, error) {
	var o listOptions
	if err := unmarshalInto(raw, &o); err != nil {
		return nil, err
	}
	var cmd tea.Cmd
	delegateChanged := false
	if o.ShowDescription != nil {
		l.delegate.ShowDescription = *o.ShowDescription
		if !*o.ShowDescription && o.ItemHeight == nil {
			l.delegate.SetHeight(1)
		}
		delegateChanged = true
	}
	if o.ItemHeight != nil {
		l.delegate.SetHeight(*o.ItemHeight)
		delegateChanged = true
	}
	if o.ItemSpacing != nil {
		l.delegate.SetSpacing(*o.ItemSpacing)
		delegateChanged = true
	}
	if len(o.ItemStyles) > 0 {
		var s listItemStylesJSON
		if err := unmarshalInto(o.ItemStyles, &s); err != nil {
			return nil, err
		}
		st := &l.delegate.Styles
		setStyle(&st.NormalTitle, s.NormalTitle)
		setStyle(&st.NormalDesc, s.NormalDesc)
		setStyle(&st.SelectedTitle, s.SelectedTitle)
		setStyle(&st.SelectedDesc, s.SelectedDesc)
		setStyle(&st.DimmedTitle, s.DimmedTitle)
		setStyle(&st.DimmedDesc, s.DimmedDesc)
		setStyle(&st.FilterMatch, s.FilterMatch)
		delegateChanged = true
	}
	if delegateChanged {
		l.m.SetDelegate(l.delegate)
	}
	if len(o.Styles) > 0 {
		var s listStylesJSON
		if err := unmarshalInto(o.Styles, &s); err != nil {
			return nil, err
		}
		st := &l.m.Styles
		setStyle(&st.TitleBar, s.TitleBar)
		setStyle(&st.Title, s.Title)
		setStyle(&st.Spinner, s.Spinner)
		setStyle(&st.FilterPrompt, s.FilterPrompt)
		setStyle(&st.FilterCursor, s.FilterCursor)
		setStyle(&st.DefaultFilterCharacterMatch, s.DefaultFilterMatch)
		setStyle(&st.StatusBar, s.StatusBar)
		setStyle(&st.StatusEmpty, s.StatusEmpty)
		setStyle(&st.StatusBarActiveFilter, s.StatusBarActiveFilter)
		setStyle(&st.StatusBarFilterCount, s.StatusBarFilterCount)
		setStyle(&st.NoItems, s.NoItems)
		setStyle(&st.PaginationStyle, s.PaginationStyle)
		setStyle(&st.HelpStyle, s.HelpStyle)
		setStyle(&st.ActivePaginationDot, s.ActivePaginationDot)
		setStyle(&st.InactivePaginationDot, s.InactivePaginationDot)
		setStyle(&st.ArabicPagination, s.ArabicPagination)
		setStyle(&st.DividerDot, s.DividerDot)
	}
	if o.Title != nil {
		l.m.Title = *o.Title
	}
	if o.ShowTitle != nil {
		l.m.SetShowTitle(*o.ShowTitle)
	}
	if o.ShowFilter != nil {
		l.m.SetShowFilter(*o.ShowFilter)
	}
	if o.ShowStatusBar != nil {
		l.m.SetShowStatusBar(*o.ShowStatusBar)
	}
	if o.ShowPagination != nil {
		l.m.SetShowPagination(*o.ShowPagination)
	}
	if o.ShowHelp != nil {
		l.m.SetShowHelp(*o.ShowHelp)
	}
	if o.FilteringEnabled != nil {
		l.m.SetFilteringEnabled(*o.FilteringEnabled)
	}
	if o.InfiniteScrolling != nil {
		l.m.InfiniteScrolling = *o.InfiniteScrolling
	}
	if len(o.StatusBarItemName) == 2 {
		l.m.SetStatusBarItemName(o.StatusBarItemName[0], o.StatusBarItemName[1])
	}
	if o.DisableQuitKeys {
		l.m.DisableQuitKeybindings()
	}
	if o.SpinnerType != "" {
		sp, ok := spinners[o.SpinnerType]
		if !ok {
			return nil, errorf("unknown spinner type %q", o.SpinnerType)
		}
		l.m.SetSpinner(sp)
	}
	if o.AdditionalShortHelp != nil {
		bs := toBindings(o.AdditionalShortHelp)
		l.m.AdditionalShortHelpKeys = func() []key.Binding { return bs }
	}
	if o.AdditionalFullHelp != nil {
		bs := toBindings(o.AdditionalFullHelp)
		l.m.AdditionalFullHelpKeys = func() []key.Binding { return bs }
	}
	if o.Width != nil || o.Height != nil {
		w, h := l.m.Width(), l.m.Height()
		if o.Width != nil {
			w = *o.Width
		}
		if o.Height != nil {
			h = *o.Height
		}
		l.m.SetSize(w, h)
	}
	if o.Items != nil {
		cmd = l.m.SetItems(toItems(o.Items))
	}
	return cmd, applyKeyMap(&l.m.KeyMap, o.KeyMap)
}

func newList(raw json.RawMessage) (component, error) {
	l := &listComponent{delegate: list.NewDefaultDelegate()}
	l.m = list.New(nil, l.delegate, 0, 0)
	_, err := l.configure(raw)
	return l, err
}

func (l *listComponent) update(msg tea.Msg) tea.Cmd {
	var cmd tea.Cmd
	l.m, cmd = l.m.Update(msg)
	return cmd
}

func (l *listComponent) view() string { return l.m.View() }

var filterStates = map[list.FilterState]string{
	list.Unfiltered: "unfiltered", list.Filtering: "filtering", list.FilterApplied: "filter_applied",
}

func (l *listComponent) call(method string, args []json.RawMessage) (any, error) {
	switch method {
	case "configure":
		o, _ := arg[json.RawMessage](args, 0)
		return l.configure(o)
	case "state":
		var selected any
		if it, ok := l.m.SelectedItem().(listItem); ok {
			selected = it.ID
		}
		return map[string]any{
			"index": l.m.Index(), "global_index": l.m.GlobalIndex(), "cursor": l.m.Cursor(),
			"selected": selected, "filter_state": filterStates[l.m.FilterState()],
			"filter_value": l.m.FilterValue(), "setting_filter": l.m.SettingFilter(),
			"is_filtered": l.m.IsFiltered(), "width": l.m.Width(), "height": l.m.Height(),
			"page": l.m.Paginator.Page, "total_pages": l.m.Paginator.TotalPages,
		}, nil
	case "items":
		return itemIDs(l.m.Items()), nil
	case "visible_items":
		return itemIDs(l.m.VisibleItems()), nil
	case "set_items":
		items, err := arg[[]listItem](args, 0)
		if err != nil {
			return nil, err
		}
		return l.m.SetItems(toItems(items)), nil
	case "insert_item", "set_item":
		i, err := arg[int](args, 0)
		if err != nil {
			return nil, err
		}
		it, err := arg[listItem](args, 1)
		if err != nil {
			return nil, err
		}
		if method == "insert_item" {
			return l.m.InsertItem(i, it), nil
		}
		return l.m.SetItem(i, it), nil
	case "remove_item":
		i, err := arg[int](args, 0)
		if err != nil {
			return nil, err
		}
		items := l.m.Items()
		if i < 0 || i >= len(items) {
			return nil, errorf("index %d out of range", i)
		}
		id := items[i].(listItem).ID
		l.m.RemoveItem(i)
		return id, nil
	case "select":
		i, err := arg[int](args, 0)
		l.m.Select(i)
		return nil, err
	case "reset_selected":
		l.m.ResetSelected()
	case "reset_filter":
		l.m.ResetFilter()
	case "set_filter_text":
		s, err := arg[string](args, 0)
		l.m.SetFilterText(s)
		return nil, err
	case "cursor_up":
		l.m.CursorUp()
	case "cursor_down":
		l.m.CursorDown()
	case "go_to_start":
		l.m.GoToStart()
	case "go_to_end":
		l.m.GoToEnd()
	case "next_page":
		l.m.NextPage()
	case "prev_page":
		l.m.PrevPage()
	case "new_status_message":
		s, err := arg[string](args, 0)
		return l.m.NewStatusMessage(s), err
	case "start_spinner":
		return l.m.StartSpinner(), nil
	case "stop_spinner":
		l.m.StopSpinner()
	case "toggle_spinner":
		return l.m.ToggleSpinner(), nil
	case "matches_for_item":
		i, err := arg[int](args, 0)
		return l.m.MatchesForItem(i), err
	case "help_bindings":
		return map[string]any{
			"short": encodeBindings(l.m.ShortHelp()),
			"full":  encodeBindingGroups(l.m.FullHelp()),
		}, nil
	case "key_map":
		return keyMapBindings(l.m.KeyMap), nil
	default:
		return nil, errUnknownMethod
	}
	return nil, nil
}
