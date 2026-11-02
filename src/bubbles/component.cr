require "json"

module Bubbles
  class Error < Exception
  end

  # Base class of all wrapped Bubbles components. The Go model lives behind
  # a handle and is released when the Crystal object is collected.
  abstract class Component
    @handle : UInt64

    protected def initialize(kind : String, options)
      json = options.to_json
      res = JSON.parse(Tea::FFI.take!(LibTea.bt_component_new(kind, kind.bytesize, json, json.bytesize)))
      if err = res["error"]?
        raise Error.new(err.as_s)
      end
      @handle = res["handle"].as_i64.to_u64
    end

    # Passes a message to the component (keys, mouse, window size and the
    # component's own `Tea::GoMsg`s). Returns the component's command, which
    # you return (or batch) from your model's `update`.
    def update(msg : Tea::Msg) : Tea::Cmd?
      wire = msg.to_wire
      return nil unless wire
      cmd = LibTea.bt_component_update(@handle, wire, wire.bytesize)
      cmd == 0 ? nil : Tea::GoCmd.new(cmd)
    end

    def view : String
      Tea::FFI.take!(LibTea.bt_component_view(@handle))
    end

    def to_s(io : IO) : Nil
      io << view
    end

    # Changes options after creation; takes the same keywords as `new`.
    def configure(**options) : self
      call("configure", options)
      self
    end

    # Calls a Go method and returns its result.
    protected def call(method : String, *args) : JSON::Any
      call_full(method, *args)[0]
    end

    # Calls a Go method that returns a command.
    protected def call_cmd(method : String, *args) : Tea::Cmd?
      call_full(method, *args)[1]
    end

    protected def call_full(method : String, *args) : {JSON::Any, Tea::Cmd?}
      json = args.to_json
      res = JSON.parse(Tea::FFI.take!(LibTea.bt_component_call(@handle, method, method.bytesize, json, json.bytesize)))
      if err = res["error"]?
        raise Error.new(err.as_s)
      end
      cmd = res["cmd"]?.try { |c| Tea::GoCmd.new(c.as_i64.to_u64) }
      {res["result"]? || JSON::Any.new(nil), cmd}
    end

    def finalize
      LibTea.bt_component_free(@handle)
    end
  end
end
