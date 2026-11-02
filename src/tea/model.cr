module Tea
  # The application state. Include it in a class and implement `update` and
  # `view`; `init` is optional.
  #
  # The model is mutable: `update` changes the model and returns a command
  # (or `nil`).
  module Model
    # Called once before the program starts. Return an initial command.
    def init : Cmd?
      nil
    end

    # Handles a message, mutates the model and returns a command or `nil`.
    abstract def update(msg : Msg)

    # Renders the model as a string.
    abstract def view : String
  end
end
