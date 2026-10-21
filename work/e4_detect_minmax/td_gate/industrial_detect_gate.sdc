create_clock -name {mipi_byte_clk} -period 9.660 -waveform {0.000 4.830} [get_ports {I_clk}]
set_input_delay -clock {mipi_byte_clk} -max 0.000 [get_ports {I_rst_n}]
set_output_delay -clock {mipi_byte_clk} -max 0.000 [get_ports {O_xmin[*] O_xmax[*] O_ymin[*] O_ymax[*] O_area[*]}]
