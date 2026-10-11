# Auto-generated TCL for TD batch build of cartoon project
# Usage: td -cmd source build_cartoon.tcl

open_project "E:/Projects/FPGA/work/td_cartoon/td_project/camera_to_dsi_display.al"

run_synthesis -top design_top_wrapper
run_place
run_route
run_bitgen -compress

report_area -file cartoon_area.rpt
report_timing -setup -max_paths 20 -file cartoon_timing_setup.rpt
report_timing -hold  -max_paths 20 -file cartoon_timing_hold.rpt

close_project
exit
