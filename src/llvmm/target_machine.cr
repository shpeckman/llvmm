# src/llvmm/target_machine.cr
class LLVMM::TargetMachine
  def initialize(@unwrap : LibLLVMM::TargetMachineRef)
  end

  def target
    target = LibLLVMM.get_target_machine_target(self)
    target ? Target.new(target) : raise "Couldn't get target"
  end

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

  def emit_obj_to_file(llvm_mod, filename)
    emit_to_file llvm_mod, filename, LLVMM::CodeGenFileType::ObjectFile
  end

  def emit_obj_to_memory_buffer(llvm_mod) : LLVMM::MemoryBuffer
    emit_to_memory_buffer llvm_mod, LLVMM::CodeGenFileType::ObjectFile
  end

  def emit_asm_to_memory_buffer(llvm_mod) : LLVMM::MemoryBuffer
    emit_to_memory_buffer llvm_mod, LLVMM::CodeGenFileType::AssemblyFile
  end

  def emit_asm_to_file(llvm_mod, filename)
    emit_to_file llvm_mod, filename, LLVMM::CodeGenFileType::AssemblyFile
  end

  def enable_global_isel=(enable : Bool)
    LibLLVMM.set_target_machine_global_isel(self, enable ? 1 : 0)
    enable
  end

  def asm_verbosity=(verbose : Bool)
    LibLLVMM.set_target_machine_asm_verbosity(self, verbose)
    verbose
  end

  def fast_isel=(enable : Bool)
    LibLLVMM.set_target_machine_fast_isel(self, enable)
    enable
  end

  def global_isel_abort=(mode : LLVMM::GlobalISelAbortMode)
    LibLLVMM.set_target_machine_global_isel_abort(self, mode)
    mode
  end

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

  def finalize
    LibLLVMM.dispose_target_machine(@unwrap)
  end
end
