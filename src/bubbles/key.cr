require "json"

module Bubbles
  # Key bindings and key maps, in plain Crystal (like `bubbles/key`).
  module Key
    # A set of keys with help text.
    #
    # ```
    # UP = Bubbles::Key::Binding.new("up", "k", help: {"↑/k", "move up"})
    # UP.matches?(msg) # => true for "up" or "k"
    # ```
    class Binding
      getter keys : Array(String)
      getter help_key : String
      getter help_desc : String
      property? enabled : Bool

      def initialize(*keys : String, help : {String, String}? = nil, @enabled = true)
        @keys = keys.to_a
        @help_key, @help_desc = help || {"", ""}
      end

      def initialize(@keys : Array(String), @help_key = "", @help_desc = "", @enabled = true)
      end

      def self.from_json(json : JSON::Any) : Binding
        new(json["keys"]?.try(&.as_a?.try(&.map(&.as_s))) || [] of String,
          json["help_key"]?.try(&.as_s) || "", json["help_desc"]?.try(&.as_s) || "",
          !(json["disabled"]?.try(&.as_bool) || false))
      end

      # True if the binding is enabled and the message is one of its keys.
      def matches?(msg : Tea::Msg) : Bool
        enabled? && msg.is_a?(Tea::KeyMsg) && keys.includes?(msg.key)
      end

      def help=(help : {String, String})
        @help_key, @help_desc = help
      end

      def to_json(json : JSON::Builder) : Nil
        json.object do
          json.field "keys", keys
          json.field "help_key", help_key
          json.field "help_desc", help_desc
          json.field "disabled", !enabled?
        end
      end
    end

    # True if *msg* matches any of the bindings.
    def self.matches?(msg : Tea::Msg, *bindings : Binding) : Bool
      bindings.any?(&.matches?(msg))
    end

    # Something that can show help: implement `short_help` and `full_help`
    # and pass it to `Bubbles::Help#view`.
    module KeyMap
      abstract def short_help : Array(Binding)
      abstract def full_help : Array(Array(Binding))
    end

    # :nodoc:
    def self.parse_help(json : JSON::Any) : {Array(Binding), Array(Array(Binding))}
      short = json["short"].as_a.map { |b| Binding.from_json(b) }
      full = json["full"].as_a.map(&.as_a.map { |b| Binding.from_json(b) })
      {short, full}
    end
  end
end
