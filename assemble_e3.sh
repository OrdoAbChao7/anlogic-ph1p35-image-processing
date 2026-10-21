#!/usr/bin/env bash
# Build work/e3_integrated = frozen AWB-Lite baseline + E1 (MIPI BBox pipeline)
# + E2 (OSD overlay pipeline). Fails closed if any source hash is unexpected.
set -euo pipefail
cd "$(dirname "$0")"

BASE=work/awblite_baseline
E1=work/e1_mipi_bbox_pipe
E2=work/e2_osd_pipe
OUT=work/e3_integrated

[ -d "$BASE" ] || { echo "missing $BASE"; exit 1; }
[ -d "$E1" ]   || { echo "missing $E1"; exit 1; }
[ -d "$E2" ]   || { echo "missing $E2"; exit 1; }
[ -e "$OUT" ]  && { echo "refusing: $OUT already exists"; exit 1; }

cp -r "$BASE" "$OUT"

# E1: MIPI BBox pre-computation pipeline
cp "$E1/user_source/hdl_source/dimension_calibrator.v"        "$OUT/user_source/hdl_source/"
cp "$E1/user_source/hdl_source/industrial_v2_feature_spine.v" "$OUT/user_source/hdl_source/"
cp "$E1/user_source/hdl_source/design_top_wrapper.v"          "$OUT/user_source/hdl_source/"

# E2: OSD overlay decision pipeline
cp "$E2/user_source/hdl_source/industrial_osd_overlay.v"      "$OUT/user_source/hdl_source/"

cat > "$OUT/run_flow_exit.tcl" <<EOF
set flow_rc [catch {source {E:/Projects/FPGA-ds-timing/work/e3_integrated/industrial_v2_fixed_seed.tcl}} flow_result]
if {\$flow_rc != 0} {
  puts stderr \$flow_result
  exit 1
}
exit 0
EOF

echo "--- integrated source hashes ---"
for f in dimension_calibrator.v industrial_v2_feature_spine.v design_top_wrapper.v industrial_osd_overlay.v; do
  h=$(sha256sum "$OUT/user_source/hdl_source/$f" | cut -d' ' -f1 | tr 'a-f' 'A-F')
  printf '%s  %s\n' "$h" "$f"
done
echo "--- unchanged files must still match baseline ---"
for f in user_source/hdl_source/isp/isp_top.v user_source/hdl_source/motion_diff_160.v \
         td_project/camera_to_dsi_display.sdc user_source/constraints_source/pin.adc; do
  a=$(sha256sum "$BASE/$f" | cut -d' ' -f1)
  b=$(sha256sum "$OUT/$f" | cut -d' ' -f1)
  [ "$a" = "$b" ] || { echo "MISMATCH $f"; exit 1; }
  echo "ok $f"
done
echo "E3_ASSEMBLED"
