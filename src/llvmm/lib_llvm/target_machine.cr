# src/llvmm/lib_llvm/target_machine.cr
require "./target"
require "./types"

lib LibLLVMM
  type TargetMachineRef = Void*
  type TargetRef = Void*
  type TargetMachineOptionsRef = Void*

  fun get_first_target = LLVMGetFirstTarget : TargetRef
  fun get_next_target = LLVMGetNextTarget(t : TargetRef) : TargetRef
  fun get_target_from_triple = LLVMGetTargetFromTriple(triple : Char*, t : TargetRef*, error_message : Char**) : Bool
  fun get_target_name = LLVMGetTargetName(t : TargetRef) : Char*
  fun get_target_description = LLVMGetTargetDescription(t : TargetRef) : Char*
  fun target_has_jit = LLVMTargetHasJIT(t : TargetRef) : Bool
  fun target_has_target_machine = LLVMTargetHasTargetMachine(t : TargetRef) : Bool
  fun target_has_asm_backend = LLVMTargetHasAsmBackend(t : TargetRef) : Bool

  fun create_target_machine_options = LLVMCreateTargetMachineOptions : TargetMachineOptionsRef
  fun dispose_target_machine_options = LLVMDisposeTargetMachineOptions(options : TargetMachineOptionsRef)
  fun create_target_machine_with_options = LLVMCreateTargetMachineWithOptions(t : TargetRef, triple : Char*, options : TargetMachineOptionsRef) : TargetMachineRef
  fun target_machine_options_set_cpu = LLVMTargetMachineOptionsSetCPU(options : TargetMachineOptionsRef, cpu : Char*)
  fun target_machine_options_set_features = LLVMTargetMachineOptionsSetFeatures(options : TargetMachineOptionsRef, features : Char*)
  fun target_machine_options_set_abi = LLVMTargetMachineOptionsSetABI(options : TargetMachineOptionsRef, abi : Char*)
  fun target_machine_options_set_code_gen_opt_level = LLVMTargetMachineOptionsSetCodeGenOptLevel(options : TargetMachineOptionsRef, level : LLVMM::CodeGenOptLevel)
  fun target_machine_options_set_reloc_mode = LLVMTargetMachineOptionsSetRelocMode(options : TargetMachineOptionsRef, reloc : LLVMM::RelocMode)
  fun target_machine_options_set_code_model = LLVMTargetMachineOptionsSetCodeModel(options : TargetMachineOptionsRef, code_model : LLVMM::CodeModel)

  fun create_target_machine = LLVMCreateTargetMachine(t : TargetRef, triple : Char*, cpu : Char*, features : Char*, level : LLVMM::CodeGenOptLevel, reloc : LLVMM::RelocMode, code_model : LLVMM::CodeModel) : TargetMachineRef
  fun dispose_target_machine = LLVMDisposeTargetMachine(t : TargetMachineRef)
  fun get_target_machine_target = LLVMGetTargetMachineTarget(t : TargetMachineRef) : TargetRef
  fun get_target_machine_triple = LLVMGetTargetMachineTriple(t : TargetMachineRef) : Char*
  fun get_target_machine_cpu = LLVMGetTargetMachineCPU(t : TargetMachineRef) : Char*
  fun create_target_data_layout = LLVMCreateTargetDataLayout(t : TargetMachineRef) : TargetDataRef
  fun set_target_machine_asm_verbosity = LLVMSetTargetMachineAsmVerbosity(t : TargetMachineRef, verbose : Bool)
  fun set_target_machine_fast_isel = LLVMSetTargetMachineFastISel(t : TargetMachineRef, enable : Bool)
  fun set_target_machine_global_isel = LLVMSetTargetMachineGlobalISel(t : TargetMachineRef, enable : Bool)
  fun set_target_machine_global_isel_abort = LLVMSetTargetMachineGlobalISelAbort(t : TargetMachineRef, mode : LLVMM::GlobalISelAbortMode)
  fun set_target_machine_machine_outliner = LLVMSetTargetMachineMachineOutliner(t : TargetMachineRef, enable : Bool)
  fun target_machine_emit_to_file = LLVMTargetMachineEmitToFile(t : TargetMachineRef, m : ModuleRef, filename : Char*, codegen : LLVMM::CodeGenFileType, error_message : Char**) : Bool
  fun target_machine_emit_to_memory_buffer = LLVMTargetMachineEmitToMemoryBuffer(t : TargetMachineRef, m : ModuleRef, codegen : LLVMM::CodeGenFileType, error_message : Char**, out_buf : MemoryBufferRef*) : Bool

  fun get_default_target_triple = LLVMGetDefaultTargetTriple : Char*
  fun normalize_target_triple = LLVMNormalizeTargetTriple(triple : Char*) : Char*
  fun get_host_cpu_name = LLVMGetHostCPUName : Char*
  fun get_host_cpu_features = LLVMGetHostCPUFeatures : Char*
end
