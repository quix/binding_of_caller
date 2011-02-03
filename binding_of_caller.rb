
require 'continuation'

# Binding.of_caller
# =================
#
# For Ruby-1.9.2 or higher.
#
# NOTE: Requires bug fix http://redmine.ruby-lang.org/issues/show/4347
# Without it, Binding.of_caller will succeed only once.
#
# Binding.of_caller passes the caller's binding to the given block.
#
#   def f
#     x = 33
#     g
#   end
#   
#   def g
#     Binding.of_caller do |binding|
#       eval("x", binding)
#     end
#   end
#   
#   p f  # => 33
#
# Restrictions:
#
# (1) Statements cannot appear after the Binding.of_caller block.
#
#   def f
#     x = 33
#     g
#   end
#   
#   def g
#     Binding.of_caller do |binding|
#       eval("x", binding)
#     end
#     puts "hello"  # <-- error
#   end
#
# (2) The method using Binding.of_caller cannot appear inside a method
#     call (this is effectively the same as (1)).
#
#   def f
#     x = 33
#     run(g)  # <-- error
#   end
#   
#   def h
#     x = 33
#     result = g  
#     run(result)  # OK
#   end
#   
#   def g
#     Binding.of_caller do |binding|
#       eval("x", binding)
#     end
#   end
#
# (3) The method using Binding.of_caller cannot be called from the
#     last line of a block or global scope.
#
#   def f
#     1.times do
#       x = 33
#       g  # <-- error: last line of block
#     end
#   end
#
#   def h
#     1.times do
#       x = 33
#       g  # <-- OK
#       nil
#     end
#   end
#
#   def g
#     Binding.of_caller do |binding|
#       eval("x", binding)
#     end
#   end
#
# ==
# Author: James M. Lawrence <quixoticsycophant@gmail.com>
# Original Binding.of_caller by Florian Gross.
#
def Binding.of_caller
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
          "Invalid use of Binding.of_caller. One of the following:\n" <<
          "  (1) statements exist after the Binding.of_caller block;\n" <<
          "  (2) the method using Binding.of_caller appears inside\n" <<
          "      a method call;\n" <<
          "  (3) the method using Binding.of_caller is called from the\n" << 
          "      last line of a block or global scope.\n" <<
          "See the documentation for Binding.of_caller.\n"
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
