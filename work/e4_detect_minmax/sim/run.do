onerror {quit -code 1}
transcript file transcript.log
vlib work
vlog -work work +define+MORPH_SIMULATION morph_open_96.v color_detect_96_v2_baseline.v color_detect_96_v2_candidate.v tb_e4_detect_diff.v
vsim -c work.tb_e4_detect_diff
run -all
quit -f
