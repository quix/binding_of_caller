
require 'continuation'

module BindingOfCaller
  VERSION = "0.1.3"

  module_function
  
  def binding_of_caller
    cont = nil
    event_count = 0
  
    tracer = lambda do |event, _, _, _, binding, _|
      event_count += 1
      if event_count == 4
        Thread.current.set_trace_func(nil)
        case event
        when "return", "line", "end"
          cont.call(nil, binding)
        else
          error_msg = "\n" <<
            "Invalid use of binding_of_caller. One of the following:\n" <<
            "  (1) statements exist after the binding_of_caller block;\n" <<
            "  (2) the method using binding_of_caller appears inside\n" <<
            "      a method call;\n" <<
            "  (3) the method using binding_of_caller is called from the\n" << 
            "      last line of a block or global scope.\n" <<
            "See the documentation for binding_of_caller.\n"
          cont.call(nil, nil, lambda { raise(ScriptError, error_msg) })
        end
      end
    end
  
    cont, result, error = callcc { |cc| cc }
    if cont
      Thread.current.set_trace_func(tracer)
    elsif result
      yield result
    else
      error.call 
    end
  end
end
