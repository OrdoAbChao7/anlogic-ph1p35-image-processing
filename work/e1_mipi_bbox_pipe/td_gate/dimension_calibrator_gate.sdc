create_clock -name {cal_clk} -period 9.660 -waveform {0.000 4.830} [get_ports {I_clk}]
set_input_delay -clock {cal_clk} -max 0.000 [get_ports {I_result_valid I_calibration_valid I_xmin[*] I_xmax[*] I_ymin[*] I_ymax[*] I_area[*]}]
set_output_delay -clock {cal_clk} -max 0.000 [get_ports {O_shape_valid}]
