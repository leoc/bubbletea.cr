module Bubbles
  # A simple list entry with a title and a description.
  record ListItem, title : String, description : String = "" do
    def filter_value : String
      title
    end
  end

  # A browsable, filterable list (`bubbles/list`) with pagination, status bar
  # and help.
  #
  # Items can be any type with a `title` (and optionally `description` and
  # `filter_value`), or plain strings. The Crystal objects stay in Crystal;
  # Go only sees their texts.
  #
  # ```
  # list = Bubbles::List(Bubbles::ListItem).new(items, title: "Groceries", width: 40, height: 20)
  # list.selected_item # => the Crystal object
  # ```
  class List(T) < Component
    include Key::KeyMap

    enum FilterState
      Unfiltered
      Filtering
      FilterApplied
    end

    @items = {} of UInt64 => T
    @next_id = 0_u64

    # *styles* keys: `title_bar`, `title`, `spinner`, `filter_prompt`,
    # `filter_cursor`, `default_filter_character_match`, `status_bar`,
    # `status_empty`, `status_bar_active_filter`, `status_bar_filter_count`,
    # `no_items`, `pagination`, `help`, `active_pagination_dot`,
    # `inactive_pagination_dot`, `arabic_pagination`, `divider_dot`.
    #
    # *item_styles* keys: `normal_title`, `normal_desc`, `selected_title`,
    # `selected_desc`, `dimmed_title`, `dimmed_desc`, `filter_match`.
    def initialize(items : Enumerable(T) = [] of T, *, title : String? = nil,
                   width : Int32 = 0, height : Int32 = 0,
                   show_title : Bool? = nil, show_filter : Bool? = nil,
                   show_status_bar : Bool? = nil, show_pagination : Bool? = nil,
                   show_help : Bool? = nil, filtering_enabled : Bool? = nil,
                   infinite_scrolling : Bool? = nil, status_bar_item_name : {String, String}? = nil,
                   disable_quit_keybindings : Bool = false, show_description : Bool? = nil,
                   item_height : Int32? = nil, item_spacing : Int32? = nil,
                   styles : Hash(String, Lipgloss::Style)? = nil,
                   item_styles : Hash(String, Lipgloss::Style)? = nil,
                   key_map : Hash(String, Key::Binding)? = nil,
                   spinner : Spinner::Type? = nil,
                   additional_short_help : Array(Key::Binding)? = nil,
                   additional_full_help : Array(Array(Key::Binding))? = nil)
      super("list", {title: title, items: wire_items(items), width: width, height: height,
                     show_title: show_title, show_filter: show_filter,
                     show_status_bar: show_status_bar, show_pagination: show_pagination,
                     show_help: show_help, filtering_enabled: filtering_enabled,
                     infinite_scrolling: infinite_scrolling,
                     status_bar_item_name: status_bar_item_name.try(&.to_a),
                     disable_quit_keybindings: disable_quit_keybindings,
                     show_description: show_description, item_height: item_height,
                     item_spacing: item_spacing, styles: styles, item_styles: item_styles,
                     key_map: key_map, spinner: spinner.try(&.to_s.underscore),
                     additional_short_help: additional_short_help,
                     additional_full_help: additional_full_help.try(&.flatten)})
    end

    private def wire_item(item : T) : NamedTuple(id: UInt64, title: String, description: String, filter_value: String)
      id = (@next_id += 1)
      @items[id] = item
      if item.is_a?(String)
        {id: id, title: item, description: "", filter_value: item}
      else
        title = item.title.to_s
        desc = item.responds_to?(:description) ? item.description.to_s : ""
        filter = item.responds_to?(:filter_value) ? item.filter_value.to_s : title
        {id: id, title: title, description: desc, filter_value: filter}
      end
    end

    private def wire_items(items : Enumerable(T))
      items.map { |i| wire_item(i) }
    end

    private def lookup(ids : JSON::Any) : Array(T)
      (ids.as_a? || [] of JSON::Any).compact_map { |id| @items[id.as_i64.to_u64]? }
    end

    # All items in order.
    def items : Array(T)
      lookup(call("items"))
    end

    # The items shown with the current filter.
    def visible_items : Array(T)
      lookup(call("visible_items"))
    end

    # Replaces all items; returns a command (re-filtering) to pass on.
    def set_items(items : Enumerable(T)) : Tea::Cmd?
      @items.clear
      call_cmd("set_items", wire_items(items))
    end

    def insert_item(index : Int32, item : T) : Tea::Cmd?
      call_cmd("insert_item", index, wire_item(item))
    end

    def set_item(index : Int32, item : T) : Tea::Cmd?
      old = call("items").as_a[index]?.try(&.as_i64.to_u64)
      cmd = call_cmd("set_item", index, wire_item(item))
      @items.delete(old) if old
      cmd
    end

    def remove_item(index : Int32) : T?
      id = call("remove_item", index).as_i64.to_u64
      @items.delete(id)
    end

    private def state : JSON::Any
      call("state")
    end

    def selected_item : T?
      state["selected"].as_i64?.try { |id| @items[id.to_u64]? }
    end

    # Index of the selection among the visible items.
    def index : Int32
      state["index"].as_i
    end

    # Index of the selection among all items.
    def global_index : Int32
      state["global_index"].as_i
    end

    # Cursor position on the current page.
    def cursor : Int32
      state["cursor"].as_i
    end

    def select(index : Int32) : Nil
      call("select", index)
    end

    def filter_state : FilterState
      FilterState.parse(state["filter_state"].as_s.camelcase)
    end

    def filter_value : String
      state["filter_value"].as_s
    end

    # True while the user is typing a filter. Use it to ignore your own
    # key bindings (e.g. "q") during filtering.
    def setting_filter? : Bool
      state["setting_filter"].as_bool
    end

    def filtered? : Bool
      state["is_filtered"].as_bool
    end

    def set_filter_text(text : String) : Nil
      call("set_filter_text", text)
    end

    def reset_filter : Nil
      call("reset_filter")
    end

    def page : Int32
      state["page"].as_i
    end

    def total_pages : Int32
      state["total_pages"].as_i
    end

    def set_size(width : Int32, height : Int32) : Nil
      configure(width: width, height: height)
    end

    def width : Int32
      state["width"].as_i
    end

    def height : Int32
      state["height"].as_i
    end

    def title=(title : String) : String
      configure(title: title)
      title
    end

    {% for m in %w(cursor_up cursor_down go_to_start go_to_end next_page prev_page reset_selected stop_spinner) %}
      def {{ m.id }} : Nil
        call({{ m }})
      end
    {% end %}

    # Shows a message in the status bar for a while.
    def new_status_message(text : String) : Tea::Cmd?
      call_cmd("new_status_message", text)
    end

    def start_spinner : Tea::Cmd?
      call_cmd("start_spinner")
    end

    def toggle_spinner : Tea::Cmd?
      call_cmd("toggle_spinner")
    end

    # Character indexes in the item's filter value that match the filter.
    def matches_for_item(index : Int32) : Array(Int32)
      call("matches_for_item", index).as_a?.try(&.map(&.as_i)) || [] of Int32
    end

    def short_help : Array(Key::Binding)
      Key.parse_help(call("help_bindings"))[0]
    end

    def full_help : Array(Array(Key::Binding))
      Key.parse_help(call("help_bindings"))[1]
    end

    def key_map : Hash(String, Key::Binding)
      call("key_map").as_h.transform_values { |b| Key::Binding.from_json(b) }
    end
  end
end
