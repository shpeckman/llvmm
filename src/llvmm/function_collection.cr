# src/llvmm/function_collection.cr
# The functions of a `Module`, obtained via `Module#functions`.
#
# A lightweight view: the module owns its functions, and this struct only
# holds a reference to it.
struct LLVMM::FunctionCollection
  def initialize(@mod : Module)
  end

  # Adds a function named *name* with the given argument types, return type,
  # and an optional variadic marker, and returns it.
  def add(name, arg_types : Array(LLVMM::Type), ret_type, varargs = false)
    # check_types_context(name, arg_types, ret_type)
    add(name, LLVMM::Type.function(arg_types, ret_type, varargs))
  end

  # Adds a function like `add(name, arg_types, ret_type, varargs)` and yields
  # it before returning it.
  def add(name, arg_types : Array(LLVMM::Type), ret_type, varargs = false, &)
    func = add(name, arg_types, ret_type, varargs)
    yield func
    func
  end

  # Adds a function named *name* with the already-built function type
  # *fun_type* (see `Type.function`) and returns it.
  def add(name, fun_type : LLVMM::Type)
    func = LibLLVMM.add_function(@mod, name, fun_type)
    Function.new(func)
  end

  # Adds a function like `add(name, fun_type)` and yields it before returning
  # it.
  def add(name, fun_type : LLVMM::Type, &)
    func = add(name, fun_type)
    yield func
    func
  end

  # The function named *name*. Raises if the module has no such function.
  def [](name)
    func = self[name]?
    func || raise "Undefined llvm function: #{name}"
  end

  # The function named *name*, or `nil` if the module has none.
  #
  # On LLVM >= 20 the lookup uses the length-based
  # `LLVMGetNamedFunctionWithLength` API (`IS_LT_200` gate); the observable
  # behavior is the same.
  def []?(name)
    func =
      {% if LibLLVMM::IS_LT_200 %}
        LibLLVMM.get_named_function(@mod, name)
      {% else %}
        LibLLVMM.get_named_function_with_length(@mod, name, name.bytesize)
      {% end %}

    func ? Function.new(func) : nil
  end

  # Iterates the module's functions in order of declaration.
  #
  # NOTE: does not `include Enumerable`; only `each` is provided.
  def each(&) : Nil
    f = LibLLVMM.get_first_function(@mod)
    while f
      yield LLVMM::Function.new f
      f = LibLLVMM.get_next_function(f)
    end
  end

  # The next lines are for ease debugging when a types/values
  # are incorrectly used across contexts.

  # private def check_types_context(name, arg_types, ret_type)
  #   ctx = @mod.context

  #   arg_types.each_with_index do |arg_type, index|
  #     if arg_type.context != ctx
  #       Context.wrong(ctx, arg_type.context, "wrong context for function #{name} in #{@mod.name}, index #{index}, type #{arg_type}")
  #     end
  #   end

  #   if ret_type.context != ctx
  #     Context.wrong(ctx, ret_type.context, "wrong context for function #{name} in #{@mod.name}, return type #{ret_type}")
  #   end
  # end
end
