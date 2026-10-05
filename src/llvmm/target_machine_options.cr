# src/llvmm/target_machine_options.cr
# Options for `Target#create_target_machine_with_options`
# (wraps `LLVMTargetMachineOptionsRef`).
#
# Every option is optional; unset options keep LLVM's defaults. The
# underlying reference is disposed by the GC finalizer.
class LLVMM::TargetMachineOptions
  # Creates a fresh options object, applying any given options.
  def initialize(*, cpu : String? = nil, features : String? = nil, abi : String? = nil,
                 opt_level : LLVMM::CodeGenOptLevel? = nil,
                 reloc : LLVMM::RelocMode? = nil,
                 code_model : LLVMM::CodeModel? = nil)
    @unwrap = LibLLVMM.create_target_machine_options
    self.cpu = cpu if cpu
    self.features = features if features
    self.abi = abi if abi
    self.opt_level = opt_level if opt_level
    self.reloc = reloc if reloc
    self.code_model = code_model if code_model
  end

  # Sets the target CPU, e.g. `LLVMM.host_cpu_name` or `"generic"`.
  def cpu=(cpu : String)
    LibLLVMM.target_machine_options_set_cpu(self, cpu)
    cpu
  end

  # Sets the target feature flags, e.g. `"+avx2"`.
  def features=(features : String)
    LibLLVMM.target_machine_options_set_features(self, features)
    features
  end

  # Sets the target ABI.
  def abi=(abi : String)
    LibLLVMM.target_machine_options_set_abi(self, abi)
    abi
  end

  # Sets the code generation optimization level.
  def opt_level=(opt_level : LLVMM::CodeGenOptLevel)
    LibLLVMM.target_machine_options_set_code_gen_opt_level(self, opt_level)
    opt_level
  end

  # Sets the relocation model.
  def reloc=(reloc : LLVMM::RelocMode)
    LibLLVMM.target_machine_options_set_reloc_mode(self, reloc)
    reloc
  end

  # Sets the code model.
  def code_model=(code_model : LLVMM::CodeModel)
    LibLLVMM.target_machine_options_set_code_model(self, code_model)
    code_model
  end

  def to_unsafe
    @unwrap
  end

  def finalize
    LibLLVMM.dispose_target_machine_options(@unwrap)
  end
end
