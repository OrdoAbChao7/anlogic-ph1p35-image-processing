# Industrial Vision V2 Blockers

| Blocker | State | Unlock condition |
|---|---|---|
| PH1P35A + SC520CS + HDMI physical acceptance | OPEN | Board, camera, display and download evidence with reproducible test log |
| PHY/DDR/clock warning closure | OPEN | Per-warning source/sink/constraint explanation plus required rebuild and hardware evidence |
| External sort actuator | OPEN | HX1P35A-specific schematic/pin contract, driver electrical review and physical actuator |
| Physical dimension calibration | OPEN | Fixed workcell geometry, reference object and repeated measurements |
| Clean-environment TD rebuild | OPEN | Self-contained package and repeated build from recorded inputs |
| Frozen baseline consistency | OPEN | The V1 Bitstream hash matches its manifest and the current full suite passes 162 tests; still document the historical source/contract drift and formally scope how V2 changes enter release without modifying the frozen V1 baseline |
| G8 integrated telemetry/AWB area and timing | OPEN | Latest isolated fix8 stops at PHY-9053 with 22,420/21,216 placed slices (105.68%) and gate Setup WNS -7,216 ps; preserve all seven features while meeting Slice/Setup/Hold gates |
| G8 fixed-frame invalid propagation | RESOLVED (RTL/SIM) | Missing-SOF error is sticky to the fixed-frame publication; exact-count no-SOF case passes `tb_frame_stats_fixed_luma.v` |
| G8 CDC reset release | RESOLVED (RTL/SIM) | Async assertion and per-domain synchronized release are covered by `tb_reset_release_sync.v` and CDC regression |
| G8 result tag and full-frame PROC ledger | RESOLVED (RTL/SIM) | Ordered depth-4 input SOF/result queue plus 921,600-cycle ledger regression; physical latency remains unmeasured |
| G8 HDMI video/E2E latency visibility | OPEN | Carry a frame ID with the selected DDR buffer slot and expose a completed HDMI output-frame event; current 4-slot writer/reader has no tag or write-complete sideband, so do not pair VSYNC with the latest input ID |
| G8 AWB update cadence | RESOLVED (RTL/SIM) | Same-edge SOF uses pre-edge gain; first later accepted SOF uses new gain, tested jointly without assuming a minimum frame gap |
| G8 AWB arithmetic resource/timing | OPEN | Exact 10-bit RGB target average improves fix8 timing, but P&R remains over area and negative setup; continue equivalent arithmetic/storage optimization |
