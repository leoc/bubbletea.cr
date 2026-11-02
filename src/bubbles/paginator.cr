module Bubbles
  # Pagination state and rendering (`bubbles/paginator`).
  class Paginator < Component
    enum Type
      Arabic
      Dots
    end

    def initialize(*, type : Type = Type::Arabic, per_page : Int32? = nil, total_pages : Int32? = nil,
                   page : Int32? = nil, active_dot : String? = nil, inactive_dot : String? = nil,
                   arabic_format : String? = nil, key_map : Hash(String, Key::Binding)? = nil)
      super("paginator", {type: type.to_s.downcase, per_page: per_page, total_pages: total_pages,
                          page: page, active_dot: active_dot, inactive_dot: inactive_dot,
                          arabic_format: arabic_format, key_map: key_map})
    end

    private def state : JSON::Any
      call("state")
    end

    # Current page, starting at 0.
    def page : Int32
      state["page"].as_i
    end

    def page=(value : Int32) : Int32
      configure(page: value)
      value
    end

    def per_page : Int32
      state["per_page"].as_i
    end

    def per_page=(value : Int32) : Int32
      configure(per_page: value)
      value
    end

    def total_pages : Int32
      state["total_pages"].as_i
    end

    # Computes the number of pages for *items* items and stores it.
    def set_total_pages(items : Int32) : Int32
      call("set_total_pages", items).as_i
    end

    def items_on_page(total_items : Int32) : Int32
      call("items_on_page", total_items).as_i
    end

    # Index range of the current page for a collection of *length* items.
    def slice_bounds(length : Int32) : Range(Int32, Int32)
      b = call("slice_bounds", length).as_a
      b[0].as_i...b[1].as_i
    end

    def on_first_page? : Bool
      state["on_first_page"].as_bool
    end

    def on_last_page? : Bool
      state["on_last_page"].as_bool
    end

    def next_page : Nil
      call("next_page")
    end

    def prev_page : Nil
      call("prev_page")
    end
  end
end
