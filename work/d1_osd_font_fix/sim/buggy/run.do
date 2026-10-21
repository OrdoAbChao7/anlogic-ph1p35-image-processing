onerror {quit -code 1}
transcript file transcript.log
vlib work
vlog -work work anlogic_logo_rom.v industrial_osd_overlay.v tb_d1_osd_font.v
vsim -c work.tb_d1_osd_font
run -all
quit -f
