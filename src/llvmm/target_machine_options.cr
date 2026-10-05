# src/llvmm/target_machine_options.cr
class LLVMM::TargetMachineOptions
  def initialize(*, cpu : String? = nil, features : String? = nil, abi : String? = nil,
                 opt_level  : LLVMM::CodeGenOptLevel? = nil,
                 reloc      : LLVMM::RelocMode?       = nil,
                 code_model : LLVMM::CodeModel?       = nil)
    @unwrap = LibLLVMM.create_target_machine_options
    self.cpu = cpu if cpu
    self.features = features if features
    self.abi = abi if abi
    self.opt_level = opt_level if opt_level
    self.reloc = reloc if reloc
    self.code_model = code_model if code_model
  end

  def cpu=(cpu : String)
    LibLLVMM.target_machine_options_set_cpu(self, cpu)
    cpu
  end

  def features=(features : String)
    LibLLVMM.target_machine_options_set_features(self, features)
    features
  end

  def abi=(abi : String)
    LibLLVMM.target_machine_options_set_abi(self, abi)
    abi
  end

  def opt_level=(opt_level : LLVMM::CodeGenOptLevel)
    LibLLVMM.target_machine_options_set_code_gen_opt_level(self, opt_level)
    opt_level
  end

  def reloc=(reloc : LLVMM::RelocMode)
    LibLLVMM.target_machine_options_set_reloc_mode(self, reloc)
    reloc
  end

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
