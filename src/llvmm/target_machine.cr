# src/llvmm/target_machine.cr
# Code generation configuration for a concrete target, triple and CPU
# (wraps `LLVMTargetMachineRef`).
#
# Created via `Target#create_target_machine` or
# `Target#create_target_machine_with_options`. The underlying reference is
# disposed by the GC finalizer; no manual cleanup is needed or possible.
class LLVMM::TargetMachine
  # Wraps the given raw reference, taking ownership of it.
  def initialize(@unwrap : LibLLVMM::TargetMachineRef)
  end

  # The `Target` this machine was created from.
  def target
    target = LibLLVMM.get_target_machine_target(self)
    target ? Target.new(target) : raise "Couldn't get target"
  end

  # The data layout of this machine, created lazily and memoized.
  def data_layout : LLVMM::TargetData
    @layout ||= begin
      layout = LibLLVMM.create_target_data_layout(self)
      layout ? TargetData.new(layout) : raise "Missing layout for #{self}"
    end
  end

  def triple : String
    triple_c = LibLLVMM.get_target_machine_triple(self)
    LLVMM.string_and_dispose(triple_c)
  end

  def cpu : String
    cpu_c = LibLLVMM.get_target_machine_cpu(self)
    LLVMM.string_and_dispose(cpu_c)
  end

  # Emits *llvm_mod* as an object file written to *filename*.
  #
  # Raises with LLVM's error message on failure; returns `true` otherwise.
  def emit_obj_to_file(llvm_mod, filename)
    emit_to_file llvm_mod, filename, LLVMM::CodeGenFileType::ObjectFile
  end

  # Emits *llvm_mod* as an object file into a new `MemoryBuffer` owned by
  # the caller.
  #
  # Raises with LLVM's error message on failure.
  def emit_obj_to_memory_buffer(llvm_mod) : LLVMM::MemoryBuffer
    emit_to_memory_buffer llvm_mod, LLVMM::CodeGenFileType::ObjectFile
  end

  # Emits *llvm_mod* as assembly text into a new `MemoryBuffer` owned by
  # the caller.
  #
  # Raises with LLVM's error message on failure.
  def emit_asm_to_memory_buffer(llvm_mod) : LLVMM::MemoryBuffer
    emit_to_memory_buffer llvm_mod, LLVMM::CodeGenFileType::AssemblyFile
  end

  # Emits *llvm_mod* as assembly text written to *filename*.
  #
  # Raises with LLVM's error message on failure; returns `true` otherwise.
  def emit_asm_to_file(llvm_mod, filename)
    emit_to_file llvm_mod, filename, LLVMM::CodeGenFileType::AssemblyFile
  end

  # Enables or disables GlobalISel instruction selection.
  def enable_global_isel=(enable : Bool)
    LibLLVMM.set_target_machine_global_isel(self, enable ? 1 : 0)
    enable
  end

  # Enables or disables verbose assembly output.
  def asm_verbosity=(verbose : Bool)
    LibLLVMM.set_target_machine_asm_verbosity(self, verbose)
    verbose
  end

  # Enables or disables FastISel instruction selection.
  def fast_isel=(enable : Bool)
    LibLLVMM.set_target_machine_fast_isel(self, enable)
    enable
  end

  # Sets what GlobalISel does when it cannot select an instruction.
  def global_isel_abort=(mode : LLVMM::GlobalISelAbortMode)
    LibLLVMM.set_target_machine_global_isel_abort(self, mode)
    mode
  end

  # Enables or disables the machine outliner.
  def machine_outliner=(enable : Bool)
    LibLLVMM.set_target_machine_machine_outliner(self, enable)
    enable
  end

  private def emit_to_file(llvm_mod, filename, type)
    status = LibLLVMM.target_machine_emit_to_file(self, llvm_mod, filename, type, out error_msg)
    unless status == 0
      raise LLVMM.string_and_dispose(error_msg)
    end
    true
  end

  private def emit_to_memory_buffer(llvm_mod, type)
    failed = LibLLVMM.target_machine_emit_to_memory_buffer(self, llvm_mod, type, out error_msg, out buf)
    raise LLVMM.string_and_dispose(error_msg) unless failed == 0
    LLVMM::MemoryBuffer.new(buf)
  end

  def to_unsafe
    @unwrap
  end

  # Disposes the underlying target machine. Called by the GC.
  def finalize
    LibLLVMM.dispose_target_machine(@unwrap)
  end
end
