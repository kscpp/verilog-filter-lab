#!/usr/bin/env bash

set -Eeuo pipefail

stage=setup

finish() {
  rc=$?
  trap - EXIT
  printf '{"stage":"%s","exit_code":%d}\n' \
    "$stage" "$rc" > /out/status.json
  exit "$rc"
}

trap finish EXIT

{
  iverilog -V
  verilator --version
  yosys -V
} > versions.log 2>&1

stage=lint

timeout 30s verilator --lint-only -Wall -Wno-fatal \
  --language 1364-2005 --top-module moving_average_8 \
  /src/dut.v > lint.log 2>&1

stage=compile

timeout 30s iverilog -g2005-sv -s tb_filter \
  -o sim.vvp /src/tb_filter.v /src/dut.v \
  > compile.log 2>&1

stage=simulation

timeout 60s vvp sim.vvp > simulation.log 2>&1

grep -qx 'TESTS_PASSED' simulation.log
test -s samples.csv

stage=synthesis

timeout 60s yosys -p '
  read_verilog /src/dut.v;
  hierarchy -check -top moving_average_8;
  proc;
  select -assert-none t:$dlatch t:$adlatch t:$dlatchsr;
  synth -top moving_average_8;
  check -assert;
  stat;
  write_json netlist.json
' > synthesis.log 2>&1

stage=done
