create_clock -name {hdmi_pixel_clk} -period 13.333 -waveform {0.000 6.666} [get_ports {I_clk}]
set_input_delay -clock {hdmi_pixel_clk} -max 0.000 [get_ports {I_rst_n}]
set_output_delay -clock {hdmi_pixel_clk} -max 0.000 [get_ports {O_vsync O_hsync O_de O_rgb[*]}]
