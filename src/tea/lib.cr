# Low-level bindings to libbubbletea_go (see go/ and DESIGN.md).
#
# The library is found through, in this order:
# - `BUBBLETEA_LIB_DIR` at compile time (adds `-L` and an rpath),
# - the shard's own `go/build` directory (filled by `make` / postinstall),
# - the regular linker search path (`CRYSTAL_LIBRARY_PATH`, `LIBRARY_PATH`).
{% begin %}
  {% if env("BUBBLETEA_LIB_DIR") %}
    @[Link(ldflags: "-L{{env("BUBBLETEA_LIB_DIR").id}} -Wl,-rpath,{{env("BUBBLETEA_LIB_DIR").id}}")]
  {% end %}
  @[Link(ldflags: "-L{{__DIR__.id}}/../../go/build -Wl,-rpath,{{__DIR__.id}}/../../go/build")]
  @[Link("bubbletea_go")]
lib LibTea
  fun dup(fd : LibC::Int) : LibC::Int
  fun bt_free(p : LibC::Char*) : Void
  fun bt_versions : LibC::Char*
  fun bt_handle_counts : LibC::Char*

  # messages and commands
  fun bt_key_parse(s : LibC::Char*, n : LibC::Int) : LibC::Char*
  fun bt_msg_free(handle : LibC::ULongLong) : Void
  fun bt_cmd_free(handle : LibC::ULongLong) : Void

  # program
  fun bt_program_new(opts : LibC::Char*, n : LibC::Int) : LibC::ULongLong
  fun bt_program_notify_fd(id : LibC::ULongLong) : LibC::Int
  fun bt_program_start(id : LibC::ULongLong, view : LibC::Char*, view_len : LibC::Int, cmds : LibC::Char*, cmds_len : LibC::Int) : LibC::Int
  fun bt_program_poll(id : LibC::ULongLong) : LibC::Char*
  fun bt_program_update(id : LibC::ULongLong, view : LibC::Char*, view_len : LibC::Int, cmds : LibC::Char*, cmds_len : LibC::Int) : LibC::Int
  fun bt_program_kill(id : LibC::ULongLong) : LibC::Int
  fun bt_program_wait(id : LibC::ULongLong, timeout_ms : LibC::Int) : LibC::Int
  fun bt_program_free(id : LibC::ULongLong) : Void
  fun bt_shutdown : Void

  # lipgloss
  fun bt_style_render(style : LibC::Char*, style_len : LibC::Int, text : LibC::Char*, text_len : LibC::Int) : LibC::Char*
  fun bt_style_frame_size(style : LibC::Char*, style_len : LibC::Int) : LibC::Char*
  fun bt_lipgloss_set_color_profile(p : LibC::Int) : Void
  fun bt_lipgloss_color_profile : LibC::Int
  fun bt_lipgloss_set_dark_background(dark : LibC::Int) : Void
  fun bt_lipgloss_has_dark_background : LibC::Int
  fun bt_lipgloss_layout(spec : LibC::Char*, n : LibC::Int) : LibC::Char*
  fun bt_lipgloss_size(s : LibC::Char*, n : LibC::Int) : LibC::Char*
  fun bt_lipgloss_table(spec : LibC::Char*, n : LibC::Int) : LibC::Char*
end
{% end %}

module Tea
  # Helpers around `LibTea` for string ownership (see DESIGN.md).
  module FFI
    # Copies a string returned by Go and releases the Go allocation.
    def self.take(ptr : LibC::Char*) : String?
      return nil if ptr.null?
      String.new(ptr).tap { LibTea.bt_free(ptr) }
    end

    def self.take!(ptr : LibC::Char*) : String
      take(ptr) || ""
    end

    # Calls a Go function that takes one string (pointer + length) and
    # returns a string owned by the caller.
    def self.call(s : String, & : LibC::Char*, Int32 -> LibC::Char*) : String
      take!(yield s.to_unsafe, s.bytesize.to_i32)
    end

    # Registry sizes on the Go side (messages, commands, programs, components).
    def self.handle_counts : Hash(String, Int32)
      Hash(String, Int32).from_json(take!(LibTea.bt_handle_counts))
    end
  end
end
