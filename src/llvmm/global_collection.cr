# src/llvmm/global_collection.cr
struct LLVMM::GlobalCollection
  def initialize(@mod : Module)
  end

  def add(type, name)
    # check_type_context(type, name)

    Value.new LibLLVMM.add_global(@mod, type, name)
  end

  def add_in_address_space(type, name, address_space)
    Value.new LibLLVMM.add_global_in_address_space(@mod, type, name, address_space)
  end

  def first : Value?
    global = LibLLVMM.get_first_global(@mod)
    global.null? ? nil : Value.new(global)
  end

  def last : Value?
    global = LibLLVMM.get_last_global(@mod)
    global.null? ? nil : Value.new(global)
  end

  def each(& : Value ->) : Nil
    global = LibLLVMM.get_first_global(@mod)
    until global.null?
      yield Value.new(global)
      global = LibLLVMM.get_next_global(global)
    end
  end

  def []?(name)
    global =
      {% if LibLLVMM::IS_LT_200 %}
        LibLLVMM.get_named_global(@mod, name)
      {% else %}
        LibLLVMM.get_named_global_with_length(@mod, name, name.bytesize)
      {% end %}

    global ? Value.new(global) : nil
  end

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
