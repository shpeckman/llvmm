# src/llvmm/target.cr
# A code generation target registered with LLVM (wraps `LLVMTargetRef`).
#
# Targets live in LLVM's global target registry and stay valid for the
# lifetime of the process; this wrapper owns nothing and disposes nothing.
# Targets only become visible after the matching initialization, e.g.
# `LLVMM.init_native_target` or `LLVMM.init_all_targets`.
#
# ```
# triple = LLVMM.default_target_triple
# target = LLVMM::Target.from_triple(triple)
# machine = target.create_target_machine(triple, LLVMM.host_cpu_name)
# ```
struct LLVMM::Target
  # Iterates over every currently registered target.
  def self.each(&)
    target = LibLLVMM.get_first_target
    while target
      yield Target.new target
      target = LibLLVMM.get_next_target target
    end
  end

  # Returns the first registered target.
  #
  # Raises if no target is registered, which usually means target
  # initialization (e.g. `LLVMM.init_native_target`) was skipped.
  def self.first : self
    first? || raise "No LLVMM targets available (did you forget to invoke LLVMM.init_native_target?)"
  end

  # Returns the first registered target, or `nil` if none is registered.
  def self.first? : self?
    target = LibLLVMM.get_first_target
    target ? Target.new(target) : nil
  end

  # Looks up the target for the given target *triple*.
  #
  # Raises `ArgumentError` if the triple is unknown or no matching target
  # has been initialized.
  def self.from_triple(triple) : self
    return_code = LibLLVMM.get_target_from_triple triple, out target, out error
    raise ArgumentError.new(LLVMM.string_and_dispose(error)) unless return_code == 0
    new target
  end

  # Wraps the given raw reference without taking ownership.
  def initialize(@unwrap : LibLLVMM::TargetRef)
  end

  def name
    String.new LibLLVMM.get_target_name(self)
  end

  def description
    String.new LibLLVMM.get_target_description(self)
  end

  def has_jit? : Bool
    LibLLVMM.target_has_jit(self) != 0
  end

  def has_target_machine? : Bool
    LibLLVMM.target_has_target_machine(self) != 0
  end

  def has_asm_backend? : Bool
    LibLLVMM.target_has_asm_backend(self) != 0
  end

  # Creates a target machine for *triple*.
  #
  # Raises if LLVM cannot create the machine. The returned machine is
  # disposed by the GC finalizer.
  def create_target_machine(triple, cpu = "", features = "",
                            opt_level = LLVMM::CodeGenOptLevel::Default,
                            reloc = LLVMM::RelocMode::PIC,
                            code_model = LLVMM::CodeModel::Default) : LLVMM::TargetMachine
    target_machine = LibLLVMM.create_target_machine(self, triple, cpu, features, opt_level, reloc, code_model)
    target_machine ? TargetMachine.new(target_machine) : raise "Couldn't create target machine"
  end

  # Creates a target machine for *triple* configured by *options* (see
  # `TargetMachineOptions`).
  #
  # Raises if LLVM cannot create the machine. The returned machine is
  # disposed by the GC finalizer.
  def create_target_machine_with_options(triple, options : TargetMachineOptions) : LLVMM::TargetMachine
    target_machine = LibLLVMM.create_target_machine_with_options(self, triple, options)
    target_machine ? TargetMachine.new(target_machine) : raise "Couldn't create target machine"
  end

  def to_s(io : IO) : Nil
    io << "LLVMM::Target(name="
    name.inspect(io)
    io << ", description="
    description.inspect(io)
    io << ')'
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  def to_unsafe
    @unwrap
  end
end
