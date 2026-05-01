from vunit import VUnit

# Create VUnit instance using QuestaSim
vu = VUnit.from_argv(compile_builtins=False)
vu.add_vhdl_builtins()

# Create a library (replaces your 'work' lib)
lib = vu.add_library("lib")

# Add all source files
lib.add_source_files("src/gpu_engine.vhd")
lib.add_source_files("src/gpu_regs.vhd")
lib.add_source_files("src/vram.vhd")
lib.add_source_files("src/vga_controller.vhd")
lib.add_source_files("src/top_gpu.vhd")

# Add testbench
lib.add_source_files("src/tb_vga.vhd")

vu.main()