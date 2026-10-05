# src/llvmm/lib_llvm/config.cr
# The list of supported targets are hardcoded in:
# https://github.com/llvm/llvm-project/blob/main/llvm/CMakeLists.txt

lib LibLLVMM
  ALL_TARGETS = [
    # default targets (as of LLVM 23)
    "AArch64",
    "AMDGPU",
    "ARM",
    "AVR",
    "BPF",
    "Hexagon",
    "Lanai",
    "LoongArch",
    "MSP430",
    "Mips",
    "NVPTX",
    "PowerPC",
    "RISCV",
    "SPIRV",
    "Sparc",
    "SystemZ",
    "VE",
    "WebAssembly",
    "X86",
    "XCore",

    # experimental targets (as of LLVM 23)
    "ARC",
    "CSKY",
    "DirectX",
    "M68k",
    "Xtensa",
  ]

  # Subset of ALL_TARGETS that ship a disassembler, per llvm/Config/Disassemblers.def
  DISASSEMBLER_TARGETS = [
    "AArch64",
    "AMDGPU",
    "ARM",
    "AVR",
    "BPF",
    "Hexagon",
    "Lanai",
    "LoongArch",
    "MSP430",
    "Mips",
    "PowerPC",
    "RISCV",
    "Sparc",
    "SystemZ",
    "VE",
    "WebAssembly",
    "X86",
    "XCore",
  ]
end
