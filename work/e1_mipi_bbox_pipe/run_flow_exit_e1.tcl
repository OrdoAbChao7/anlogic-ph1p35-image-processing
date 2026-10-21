set flow_rc [catch {source {E:/Projects/FPGA-ds-timing/work/e1_mipi_bbox_pipe/industrial_v2_fixed_seed.tcl}} flow_result]
if {$flow_rc != 0} {
  puts stderr $flow_result
  exit 1
}
exit 0
