# G3/G8 DDR-to-HDMI output-frame tag source audit

## Scope

Determine whether the current formal V2 top can truthfully pair the HDMI output-frame event with the source frame ID used by the processing-latency ledger. This was a read-only RTL/interface audit; no RTL, DDR/IP configuration, constraints, release candidate, or Bitstream was changed.

## Source observations (`project`)

- `fallback/td_source/design_top_wrapper.v` generates `ind_source_frame_id` from ISP SOF and uses it for the detector-result tag queue, frame statistics, motion adapter, and feature spine. The formal feature-spine inputs still tie `I_video_valid=0`, `I_video_vsync=0`, and `I_video_frame_id=0`.
- `fallback/td_package/user_source/hdl_source/video_in.v` maintains a 2-bit write pointer, advances it on a synchronized camera frame-start when no MIPI error is reported, and selects one of four fixed DDR base addresses. It exposes a 2-bit read pointer to `video_out`, but no frame ID, explicit frame-end, or DDR-write-complete event.
- `fallback/td_package/user_source/hdl_source/video_out.v` synchronizes display VSYNC into the DDR clock domain and selects one of four DDR base addresses from the read pointer. Its output is pixel data only; it has no frame-ID output.
- The top connects the ISP RGB stream to `video_in`, and connects the selected DDR pixels to the HDMI timing/mixer path. There is no metadata memory or sideband tying a DDR slot to the ISP input frame counter.

## Conclusion

`S_hdmi_out_vsync` can identify an output timing boundary, but the current source does not establish which tagged ISP input frame occupies the selected DDR slot at that boundary. Pairing the output VSYNC with the latest `ind_source_frame_id` would therefore be an unsupported assumption. The writer also has no explicit completed-frame/write-drained event from which to commit a slot tag.

Keep VIDEO and physical E2E latency `N/A`. A future implementation needs an explicit slot-tag lifecycle that follows the existing writer/reader pointer behavior and defines when a frame is complete, including ring wrap, writer busy, MIPI error, and read underflow cases. Then add a focused simulation proving the slot tag at each output frame boundary before wiring the event into `latency_monitor`.

## Verification boundary

- Evidence type: `project` source inspection plus `inferred` conclusion.
- No simulation, TD build, Bitstream generation, hardware measurement, or release promotion was performed for this audit.
- The existing 921,600-cycle ledger regression remains simulation-only evidence for PROC latency and does not close HDMI/video or physical E2E latency.

## Evidence locations

- `fallback/td_source/design_top_wrapper.v:746-763,835-885,1203-1230`
- `fallback/td_package/user_source/hdl_source/video_in.v:31-43,98-137,178-201`
- `fallback/td_package/user_source/hdl_source/video_out.v:31-55,116-130`
- `docs/superpowers/plans/2026-10-19-industrial-v2-g8-live-telemetry.md`
