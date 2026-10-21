# BASELINE — Industrial V2 AWB-Lite timing-closure workspace

Created: 2026-10-21
Purpose: isolated, reproducible RTL/timing work for the Anlogic PH1P35 Industrial V2
first-board bitstream. Nothing in this directory is a release candidate until it
passes the gates recorded in `CURRENT_STATE.md`.

## Provenance

| Item | Value |
|---|---|
| Source snapshot | `E:\Projects\FPGA\work\g8_r1_v2_integration\work\g8_r3_awb_lite_20261021\full_candidate` |
| Frozen copy | `work/awblite_baseline/` (238 files, immutable) |
| Parent input manifest | `731FF493EF607ED20909D4C72A60E28B85A21F76AC75C10015797096FEDC5ED1` = SHA-256 of `R1-input-manifest.json` |
| Baseline build inputs | `work/awblite_baseline/INPUTS.sha256` (all entries re-verified byte-identical before copy) |
| TD | `E:\Projects\FPGA\.tools\td\app\bin\td_commands_prompt.exe`, v6.2.168116, SHA-256 `E2E04ADA5E256DCCD017240C0F4DCFACE7F96DCA67CDE0E56E606AC0E02F827A` |
| Flow | `industrial_v2_fixed_seed.tcl` = TD `DefaultFlow.tcl` + `set_param place seed 1` |
| Device | PH1P35MDG324, speed 3 |
| ModelSim | ModelSim-Intel FPGA Starter Edition 2020.1 (`C:\intelFPGA\20.1\modelsim_ase\win32aloem`) |
| Git | worktree of `E:\Projects\FPGA`, branch `ds/industrial-v2-timing-closure`, base `48e819a` |

## Re-verified source identities (match frozen INPUTS.sha256)

```
8D9E119E58C64F6D152501C9B13CF02A27ECC4DD57DF62D880C9590626E44DB8  design_top_wrapper.v
D88E109CF9E07925EC009CA5D080DC4C92C5E31618C01D92D3022CFB3C620DAF  industrial_v2_feature_spine.v
A90047122BCF2F3FEEA8055CB5FCD0383708519CE86EB85FC57CCE59182F6DA8  dimension_calibrator.v
233482A5CA46213FBC3B4D37C594CA0337E49CB1A77E5B94EF1493CDB75E6AC5  industrial_osd_overlay.v
390DFE5FA12669AFC5E8DB01E893300132605FFB6BFB962EC40DA5BE022B068F  camera_to_dsi_display.sdc
7E41F2B65DEAEE47D5A21B7B259D1E06070C2BBB6ECEFED1659A6C30D507A30F  syn_1/camera_to_dsi_display.prj
AA7502B01565C13F4F271902134AF6E63169195C1C05B4A543B3FCE939E87C59  phy_1/camera_to_dsi_display.prj
1F07F9A70F7F2D328D2193EBA84FA261BD81C9762DFB71EE307102DE763F325B  industrial_v2_fixed_seed.tcl
```

`work/awblite_baseline/SOURCE_MANIFEST.sha256` covers all 238 files
(manifest itself: `532603AA4AB7CC60FB075DC4BF70E749E77F7364938CA200A85C08C5D3F43B56`).

## Rules of this workspace

1. `work/awblite_baseline/` is frozen. Never edit it. Copy it per experiment.
2. Every experiment records its own `INPUTS.sha256` before a TD run and
   `RESULTS.sha256` after.
3. TD runs always use `run_flow_exit.tcl`-style exit-status wrappers and never
   share a run directory between arms.
4. No false/multicycle paths, no SDC clock relaxation, no warning suppression.
5. No seed hunting. `place seed 1` stays fixed unless a seed A/B is explicitly
   pre-registered as an experiment in its own right.
