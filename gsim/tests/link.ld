/* Programs for gate-level simulation. Code and data from 0x80000000 (cached);
   tohost/fromhost at 0x60000000, outside the cached region, so the exit
   status reaches the bus also with a write-back data cache. */
OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x60000000;
  .tohost (NOLOAD) : { *(.tohost) }
  . = 0x80000000;
  .text.init : { *(.text.init) }
  .uvmif : { *(.uvmif) }
  .text : { *(.text .text.*) }
  .rodata : { *(.rodata .rodata.*) }
  .data : { *(.data .data.*) }
  .sdata : {
    __global_pointer$ = . + 0x800;
    *(.srodata .srodata.*) *(.sdata .sdata.*)
  }
  .sbss : { *(.sbss .sbss.*) *(.scommon) }
  .bss : { *(.bss .bss.*) *(COMMON) }
  .tdata : { _tdata_begin = .; *(.tdata .tdata.*) _tdata_end = .; }
  .tbss : { *(.tbss .tbss.*) _tbss_end = .; }
  _end = .;
}
