#!/bin/bash
# Build the whole-core simulation (GHDL converts the VHDL core to Verilog,
# Verilator simulates everything together). The VHDL core files are used
# unchanged.
set -e
cd "$(dirname "$0")"

GHDL_FLAGS="--std=93c -fsynopsys -frelaxed --workdir=work"
VC=../src/fpga/core/vc4000

if [ ! -f vc4000_core_synth.v ] || [ "$1" == "vhdl" ]; then
  rm -rf work && mkdir work
  ghdl -i $GHDL_FLAGS $VC/base_pack.vhd $VC/sgs2650_pack.vhd $VC/sgs2650.vhd $VC/sgs2636.vhd $VC/vc4000_core.vhd
  ghdl -m $GHDL_FLAGS vc4000_core > /dev/null 2>&1
  ghdl --synth $GHDL_FLAGS --out=verilog vc4000_core > vc4000_core_synth.v 2> synth.log
  python3 fix_synth.py vc4000_core_synth.v
  # GHDL turns VHDL length checks (always true here) into $fatal calls
  # that Verilator does not accept in Verilog-2005 files: drop them.
  sed -i 's/\$fatal(1, "assertion failure [a-z0-9]*");/;/' vc4000_core_synth.v
fi

POCKET=../src/fpga/core/pocket
verilator --binary --timing -j 2 -O2 +1364-2005ext+v \
  -Wno-fatal -Wno-WIDTH -Wno-PINMISSING -Wno-UNOPTFLAT -Wno-MULTIDRIVEN -Wno-TIMESCALEMOD \
  -Wno-CASEINCOMPLETE -Wno-COMBDLY -Wno-INITIALDLY -Wno-UNUSEDSIGNAL -Wno-DECLFILENAME \
  --top-module tb_top \
  tb_top.sv sim_stubs.v \
  ../src/fpga/apf/common.v \
  ../src/fpga/core/core_top.v \
  $POCKET/cart_loader.v $POCKET/boot_seq.v $POCKET/input_map.v \
  $POCKET/video_apf.v $POCKET/audio_apf.v \
  vc4000_core_synth.v \
  -o Vtb_top 2>&1 | grep -v '^%Warning\|^  \|^ *: \|^ *|' | tail -20
echo "built obj_dir/Vtb_top"
