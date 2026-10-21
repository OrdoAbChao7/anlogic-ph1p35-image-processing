set flow_rc [catch {source {E:/Projects/FPGA/.tools/td/app/doc/scripts/DefaultFlow.tcl}} flow_result]
if {$flow_rc != 0} {
  puts stderr $flow_result
  exit 1
}
exit 0
