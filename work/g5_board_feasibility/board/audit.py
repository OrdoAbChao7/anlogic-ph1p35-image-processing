"""Read existing artifacts only; never invoke TD or modify video projects."""
import hashlib, json, re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
PHY = 'td_project/camera_to_dsi_display_Runs/phy_1'
LAB = '.tools/td/work/lab_ex1_mipi_hdmi_sc520'
CARTOON = 'work/td_cartoon'
def sha(p): return hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
def resources(base):
    p = f'{base}/{PHY}/camera_to_dsi_display_phy.area'
    t = (ROOT/p).read_text()
    result = {}
    for name in ('lut6', 'slice reg', 'slice', 'eram', 'dsp', 'pll', 'gclk'):
        m = re.search(r'^\s*#' + re.escape(name) + r'\s+(\d+)\s+out of\s+(\d+)',t,re.M)
        used,total=map(int,m.groups());result[name]={'used':used,'total':total,'unallocated':total-used}
    return result
versions=[]
for name,base in [('lab1',LAB),('td_cartoon',CARTOON),('cartoon_release','work/output/cartoon-release')]:
    artifact_dir = base if name=='cartoon_release' else f'{base}/{PHY}'
    artifacts={f:{'path':f'{artifact_dir}/{f}','sha256':sha(f'{artifact_dir}/{f}')} for f in ('camera_to_dsi_display.bit','route.qor','final_timing.rpt')}
    versions.append({'name':name,'artifacts':artifacts,'resources':resources(CARTOON if name=='cartoon_release' else base),'resource_evidence':f'{CARTOON if name=="cartoon_release" else base}/{PHY}/camera_to_dsi_display_phy.area:15','hardware_verified':False})
frame_bytes=1280*720*3
refresh=75_000_000/(1650*750)
peak=2*(800_000_000/3)*16/8
result={'evidence_type':'project_and_inferred_no_new_hardware_measurement','versions':versions,
'eram':{'block_bits':20480,'total_blocks':108,'video_used_blocks':39,'unallocated_blocks':69,'unallocated_raw_bytes':69*20480//8,'guaranteed_ai_usable_bytes':None,'note':'Raw capacity only; width/depth packing, ports, buffering and integration reserve reduce usable storage.'},
'ddr2':{'configured_density_mbit':512,'configured_capacity_bytes':2**26,'dq_bits':16,'row_bits':13,'column_bits':10,'bank_bits':2,'hardware_capacity_tested':False,'gui_reference_mhz':100,'top_reference_mhz':50,'gui_ddr_clock_mhz':533.3,'routed_ddr_clock_mhz':266.667,'routed_ui_clock_mhz':66.667,'ui_data_bits':128,'effective_bandwidth_measured_bytes_s':None,'theoretical_peak_bytes_s':peak,'theoretical_peak_basis':'50MHz * 32 / 3 / 2 DDR CK; double data rate x16; matches routed STA. UI128 x 66.6667MHz. Clock not physically measured.','frame_bytes':frame_bytes,'frame_base_mc_word_addresses':[0,7000000,14000000,21000000],'mc_word_address_bytes':2,'address_unit_evidence':'MC_ADDR_WIDTH=25 equals row13+col10+bank2; +8 address per128b transaction; inferred x16 word units','frame_base_inferred_byte_addresses':[0,14000000,28000000,42000000],'frame_payload_total_bytes':4*frame_bytes,'frame_reserved_span_conservative_bytes':42000000+frame_bytes,'contiguous_tail_above_last_frame_bytes':2**26-(42000000+frame_bytes),'tail_allocated_to_ai':False},
'video_bandwidth':{'stored_format':'packed RGB888; 16 pixels occupy 3x128bit words','output_timing_total':[1650,750],'pixel_clock_nominal_hz':75000000,'hdmi_refresh_nominal_hz':refresh,'camera_rate_measured_hz':None,'camera_selected_table':'uics520reg_720p60; 24MHz nominal 60fps table, actual MCLK23.809524MHz; exact sensor cadence unmeasured','camera_60fps_scenario_write_bytes_s':frame_bytes*60,'hdmi_read_minimum_bytes_s':frame_bytes*refresh,'camera60_hdmi_actual_minimum_bytes_s':frame_bytes*(60+refresh),'camera30_hdmi_actual_sensitivity_bytes_s':frame_bytes*(30+refresh),'warning':'Minimum useful pixel traffic; prefetch discarded at vsync, refresh, row misses, read/write turnarounds, FIFO arbitration and AI traffic excluded. Input60 is budget scenario, not measured fact.'},
'integration_status':'BLOCKED: G1/G2/VISUAL_APPROVED and deterministic DDR arbitration/response routing/CDC/frame contracts incomplete'}
assert all(versions[1]['artifacts'][f]['sha256']==versions[2]['artifacts'][f]['sha256'] for f in versions[1]['artifacts'])
assert versions[0]['resources']['slice']['unallocated']==8826
assert versions[2]['resources']['slice']['unallocated']==6368
(OUT/'budget.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'artifact_hash_comparison':'PASS td_cartoon equals cartoon_release','lab_slice_free':8826,'cartoon_slice_free':6368,'ddr_theoretical_MB_s':peak/1e6,'hdmi_refresh_hz':refresh,'video60_minimum_MB_s':frame_bytes*(60+refresh)/1e6},ensure_ascii=False))
