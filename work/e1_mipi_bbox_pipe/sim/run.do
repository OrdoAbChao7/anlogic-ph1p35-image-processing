onerror {quit -code 1}
transcript file transcript.log
vlib work
vlog -work work dimension_calibrator_baseline.v dimension_calibrator_candidate.v tb_e1_bbox_pipe_diff.v
vsim -c work.tb_e1_bbox_pipe_diff
run -all
quit -f
