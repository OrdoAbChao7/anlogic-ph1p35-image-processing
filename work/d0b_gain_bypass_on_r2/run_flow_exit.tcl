set flow_rc [catch {source {E:/Projects/FPGA-ds-timing/work/d0b_gain_bypass_on_r2/industrial_v2_fixed_seed.tcl}} flow_result]
if {$flow_rc != 0} {
  puts stderr $flow_result
  exit 1
}
exit 0
