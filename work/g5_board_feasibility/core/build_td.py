from pathlib import Path
import subprocess,json,sys,re
D=Path(__file__).resolve().parent
ROOT=D.parents[2]
TD=ROOT/'.tools/td/app/bin/td_commands_prompt.exe'
FLOW=ROOT/'.tools/td/app/doc/scripts/DefaultFlow.tcl'
configs={'core9':('core_probe',['int8_core.v']),'ram1024x32':('ram_probe',['int8_core.v']),'packed2':('cal_mult_int8_x2',['cal_mul_int8_x2.v','cal_mul_int8_x2_dsp.v'])}
configs.update({'packed2_registered':('packed_registered',['probe_wrappers.v','cal_mul_int8_x2.v','cal_mul_int8_x2_dsp.v']), 'ram1024x32_registered':('ram_registered',['probe_wrappers.v','int8_core.v'])})
for name in sys.argv[1:] or configs:
 top,files=configs[name]; folder=D/'td'/name;folder.mkdir(parents=True,exist_ok=True)
 entries=''.join('<File Path="../../../'+f+'">\n<FileInfo>\n<Attr Name="UsedInSyn" Val="true"/>\n<Attr Name="UsedInP&R" Val="true"/>\n<Attr Name="BelongTo" Val="design_1"/>\n<Attr Name="CompileOrder" Val="1"/>\n</FileInfo>\n</File>\n' for f in files)
 prj='<?xml version="1.0" encoding="UTF-8"?><Project Version="3" Minor="2"><TD_Version>6.2.168116</TD_Version><Name>probe</Name><HardWare><Family>PH1</Family><Device>PH1P35MDG324</Device><Speed>-3</Speed></HardWare><Source_Files><Verilog>'+entries+'</Verilog></Source_Files><FileSets><FileSet Name="design_1" Type="DesignFiles"/></FileSets><TOP_MODULE><LABEL>'+top+'</LABEL><MODULE>'+top+'</MODULE><CREATEINDEX>user</CREATEINDEX></TOP_MODULE><Property/><Device_Settings/></Project>'
 template=(D/'project_template.prj').read_text()
 prj=re.sub(r'<Source_Files>.*?</Source_Files>','<Source_Files>\n<Verilog>\n'+entries+'</Verilog>\n</Source_Files>',template,flags=re.S).replace('camera_to_dsi_display','probe').replace('TOP_PLACEHOLDER',top)
 (folder/'clock.sdc').write_text('create_clock -name core_clk -period 10 [get_ports clk]\nset_input_delay -clock core_clk -max 2 [remove_from_collection [all_inputs] [get_ports clk]]\nset_input_delay -clock core_clk -min 0.5 [remove_from_collection [all_inputs] [get_ports clk]]\nset_output_delay -clock core_clk -max 2 [all_outputs]\nset_output_delay -clock core_clk -min 0.5 [all_outputs]\n')
 for phase,start,end in [('syn','read_design','opt_gate'),('phy','opt_place','opt_route')]:
  d=folder/phase;d.mkdir(exist_ok=True)
  for marker in d.glob('.*.f'): marker.unlink()
  (d/'probe.prj').write_text(prj)
  (d/'settings.cfg').write_text('set device_name ph1_35p.db\nset package_name PH1P35MDG324\nset speed 3\nset prj_name probe\nset top_model_name '+top+'\nset start_step '+start+'\nset end_step '+end+'\nset area_option -packarea\nset SDCList {../clock.sdc}\nset arr_filter false\nset drHoldFix on\nset parent ../syn\nset chipDebugger unused\n')
  with (d/'console.log').open('w') as log:
   p=subprocess.run([str(TD),FLOW.as_posix()],cwd=d,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
  (d/'exit.json').write_text(json.dumps({'returncode':p.returncode}))
  print(name,phase,p.returncode,flush=True)
  if p.returncode or not (d/('.'+end+'.end.f')).exists():raise SystemExit('TD phase failed; inspect '+str(d/'console.log'))
