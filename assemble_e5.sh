#!/usr/bin/env bash
# Build work/e5_detect_parallel = E3 (E1+E2) + E4 parallel group statistics.
# Fails closed if E3 itself is not the expected tree.
set -euo pipefail
cd "$(dirname "$0")"

E3=work/e3_integrated
E4=work/e4_detect_minmax
OUT=work/e5_detect_parallel

[ -d "$E3" ] || { echo "missing $E3"; exit 1; }
[ -d "$E4" ] || { echo "missing $E4"; exit 1; }
[ -e "$OUT" ] && { echo "refusing: $OUT already exists"; exit 1; }

cp -r "$E3" "$OUT"

# E4: statistically equivalent parallel four-pixel group accumulation.
cp "$E4/user_source/hdl_source/color_detect_96_v2.v" "$OUT/user_source/hdl_source/"

cat > "$OUT/run_flow_exit.tcl" <<EOF
set flow_rc [catch {source {E:/Projects/FPGA-ds-timing/work/e5_detect_parallel/industrial_v2_fixed_seed.tcl}} flow_result]
if {\$flow_rc != 0} {
  puts stderr \$flow_result
  exit 1
}
exit 0
EOF

# Run directories must start clean.
for arm in syn_1 phy_1 phy_bitgen phy_check; do
  rm -rf "$OUT/td_project/camera_to_dsi_display_Runs/$arm"
done
for arm in syn_1 phy_1; do
  mkdir -p "$OUT/td_project/camera_to_dsi_display_Runs/$arm"
done
cp "$E3/td_project/camera_to_dsi_display_Runs/syn_1/camera_to_dsi_display.prj" \
   "$OUT/td_project/camera_to_dsi_display_Runs/syn_1/"
cp "$E3/td_project/camera_to_dsi_display_Runs/syn_1/settings.cfg" \
   "$OUT/td_project/camera_to_dsi_display_Runs/syn_1/"
cp "$E3/td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.prj" \
   "$OUT/td_project/camera_to_dsi_display_Runs/phy_1/"
cp "$E3/td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg" \
   "$OUT/td_project/camera_to_dsi_display_Runs/phy_1/"

echo "--- E5 changed files vs baseline ---"
for f in dimension_calibrator.v industrial_v2_feature_spine.v design_top_wrapper.v \
         industrial_osd_overlay.v color_detect_96_v2.v; do
  a=$(sha256sum "work/awblite_baseline/user_source/hdl_source/$f" | cut -d' ' -f1)
  b=$(sha256sum "$OUT/user_source/hdl_source/$f" | cut -d' ' -f1)
  [ "$a" = "$b" ] && echo "unchanged $f" || printf 'changed   %s  %s\n' "$(echo $b | tr a-f A-F)" "$f"
done
echo "--- untouched identity checks ---"
for f in user_source/hdl_source/isp/isp_top.v user_source/hdl_source/motion_diff_160.v \
         user_source/hdl_source/morph_open_96.v \
         td_project/camera_to_dsi_display.sdc user_source/constraints_source/pin.adc; do
  a=$(sha256sum "work/awblite_baseline/$f" | cut -d' ' -f1)
  b=$(sha256sum "$OUT/$f" | cut -d' ' -f1)
  [ "$a" = "$b" ] || { echo "MISMATCH $f"; exit 1; }
  echo "ok $f"
done
echo "E5_ASSEMBLED"
