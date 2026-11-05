# src/llvmm/jit/module_builder.cr

# Builds a module for a `LLVMM::JIT` using Crystal types for function signatures.
@[Experimental("The C API wrapped by this type is marked as experimental by LLVM.")]
class LLVMM::JIT::ModuleBuilder
  # The module under construction. It belongs to the JIT's context and must not
  # be submitted directly; the enclosing `JIT#module` call verifies and submits it.
  getter mod : LLVMM::Module

  def initialize(@mod : LLVMM::Module, @jit : LLVMM::JIT)
  end

  # Adds a function declaration named *name*. The last entry in *types* is the
  # return type; preceding entries are argument types. Crystal types use the same
  # LLVM mapping as `JIT#function` lookup.
  def function(name : String, *types : *T) : LLVMM::Function forall T
    arg_types, ret_type = @jit.signature_types(*types)
    @mod.functions.add(name, arg_types, ret_type)
  end

  # Adds a function and yields it with a builder positioned at its `"entry"`
  # block. Returns the function.
  def function(name : String, *types : *T, &) : LLVMM::Function forall T
    func = function(name, *types)
    func.basic_blocks.append("entry") do |builder|
      yield func, builder
    end
    func
  end
end
