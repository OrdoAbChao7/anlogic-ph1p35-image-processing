onerror {quit -code 1}
transcript file transcript.log
vlib work
vlog -work work anlogic_logo_rom.v industrial_osd_overlay_baseline.v industrial_osd_overlay_candidate.v tb_osd_pipe_diff.v
vsim -c work.tb_osd_pipe_diff
run -all
quit -f
