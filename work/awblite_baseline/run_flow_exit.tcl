set flow_rc [catch {source {E:/Projects/FPGA/work/g8_r1_v2_integration/work/g8_r3_awb_lite_20261021/full_candidate/industrial_v2_fixed_seed.tcl}} flow_result]
if {$flow_rc != 0} {
  puts stderr $flow_result
  exit 1
}
exit 0
