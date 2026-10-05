# src/llvmm/global_collection.cr
# The global variables of a `Module`, obtained via `Module#globals`.
#
# A lightweight view: the module owns its globals, and this struct only
# holds a reference to it. Each global is exposed as a `Value`.
struct LLVMM::GlobalCollection
  def initialize(@mod : Module)
  end

  # Adds a global variable of the given *type* named *name* to the module
  # and returns it.
  def add(type, name)
    # check_type_context(type, name)

    Value.new LibLLVMM.add_global(@mod, type, name)
  end

  # Adds a global variable like `add`, but in the given *address_space*.
  def add_in_address_space(type, name, address_space)
    Value.new LibLLVMM.add_global_in_address_space(@mod, type, name, address_space)
  end

  # The first global of the module, or `nil` if it has none.
  def first : Value?
    global = LibLLVMM.get_first_global(@mod)
    global.null? ? nil : Value.new(global)
  end

  # The last global of the module, or `nil` if it has none.
  def last : Value?
    global = LibLLVMM.get_last_global(@mod)
    global.null? ? nil : Value.new(global)
  end

  # Iterates the module's globals in order of declaration.
  #
  # NOTE: does not `include Enumerable`; only `each` is provided.
  def each(& : Value ->) : Nil
    global = LibLLVMM.get_first_global(@mod)
    until global.null?
      yield Value.new(global)
      global = LibLLVMM.get_next_global(global)
    end
  end

  # The global named *name*, or `nil` if the module has none.
  #
  # On LLVM >= 20 the lookup uses the length-based
  # `LLVMGetNamedGlobalWithLength` API (`IS_LT_200` gate); the observable
  # behavior is the same.
  def []?(name)
    global =
      {% if LibLLVMM::IS_LT_200 %}
        LibLLVMM.get_named_global(@mod, name)
      {% else %}
        LibLLVMM.get_named_global_with_length(@mod, name, name.bytesize)
      {% end %}

    global ? Value.new(global) : nil
  end

  # The global named *name*. Raises if the module has no such global.
  def [](name)
    global = self[name]?
    if global
      global
    else
      raise "Global not found: #{name}"
    end
  end

  # The next lines are for ease debugging when a types/values
  # are incorrectly used across contexts.

  # private def check_type_context(type, name)
  #   if @mod.context != type.context
  #     Context.wrong(@mod.context, type.context, "wrong context for global #{name} in #{@mod.name}, type #{type}")
  #   end
  # end
end
