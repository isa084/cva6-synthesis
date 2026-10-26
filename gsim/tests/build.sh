#!/usr/bin/env bash
# Builds the gate-level simulation programs into gsim/tests/hex/ (committed):
# one file of 64-bit little-endian words per program, loaded at 0x80000000.
# Usage: CVA6=<cva6 checkout> [PREFIX=riscv-none-elf-] gsim/tests/build.sh
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
: "${CVA6:?set CVA6 to a CVA6 checkout}"
PREFIX=${PREFIX:-riscv-none-elf-}
src=$CVA6/verif/tests
out=$here/hex
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out"
# C flags of the riscv-tests benchmarks: no loop-to-memset rewrite inside memset.
cflags=(-O2 -std=gnu99 -fno-common -fno-builtin-printf -fno-tree-loop-distribute-patterns)
flags=(-Wl,--no-warn-rwx-segments -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -T "$here/link.ld")

hex() {  # <elf> <name>
  "${PREFIX}objcopy" -O binary -R .tohost "$1" "$tmp/$2.bin"
  truncate -s %8 "$tmp/$2.bin"
  od -An -v -tx8 -w8 "$tmp/$2.bin" | tr -d ' ' > "$out/$2.hex"
}

for xlen in 32 64; do
  abi=$([ "$xlen" = 32 ] && echo ilp32 || echo lp64)
  mem=$([ "$xlen" = 32 ] && echo "lw sw" || echo "ld sd")
  for t in add addi beq jal $mem; do
    name=rv${xlen}ui-p-$t
    "${PREFIX}gcc" -march=rv${xlen}i_zicsr_zifencei -mabi=$abi "${flags[@]}" \
      -I "$src/riscv-tests/env/p" -I "$src/riscv-tests/isa/macros/scalar" \
      "$src/riscv-tests/isa/rv${xlen}ui/$t.S" -o "$tmp/$name"
    hex "$tmp/$name" "$name"
  done
  name=rv${xlen}um-p-mul
  "${PREFIX}gcc" -march=rv${xlen}im_zicsr_zifencei -mabi=$abi "${flags[@]}" \
    -I "$src/riscv-tests/env/p" -I "$src/riscv-tests/isa/macros/scalar" \
    "$src/riscv-tests/isa/rv${xlen}um/mul.S" -o "$tmp/$name"
  hex "$tmp/$name" "$name"
  name=hello_world-rv$xlen
  "${PREFIX}gcc" -march=rv${xlen}imc_zicsr_zifencei -mabi=$abi "${cflags[@]}" "${flags[@]}" \
    -I "$src/custom/common" -I "$src/custom/env" "$src/custom/common/crt.S" "$src/custom/common/syscalls.c" \
    "$src/custom/hello_world/hello_world.c" -lgcc -o "$tmp/$name"
  hex "$tmp/$name" "$name"
done
ls "$out"
