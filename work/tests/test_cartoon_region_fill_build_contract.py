"""Build-entry contract for an isolated cartoon candidate TD run."""

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "build_industrial_td.py"
spec = importlib.util.spec_from_file_location("build_industrial_td", SCRIPT)
build_td = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = build_td
spec.loader.exec_module(build_td)


class CartoonRegionFillBuildContractTests(unittest.TestCase):
    def test_default_build_stays_on_s3_luma(self):
        args = build_td.parse_args([])
        self.assertEqual(
            Path(args.video_rtl).resolve(),
            (ROOT / "work" / "rtl" / "video_cartoon_luma.v").resolve(),
        )
        self.assertEqual(
            Path(args.work_project).resolve(),
            (ROOT / "work" / "td_industrial").resolve(),
        )

    def test_candidate_build_can_use_explicit_isolated_paths(self):
        args = build_td.parse_args(
            [
                "--video-rtl",
                "work/rtl/video_cartoon_region_fill.v",
                "--work-project",
                "work/td_industrial_region_fill",
                "--release-dir",
                "work/output/cartoon-region-fill-td",
            ]
        )
        self.assertEqual(args.video_rtl, "work/rtl/video_cartoon_region_fill.v")
        self.assertEqual(args.work_project, "work/td_industrial_region_fill")
        self.assertEqual(args.release_dir, "work/output/cartoon-region-fill-td")

    def test_source_manifest_never_includes_user_owned_vvp(self):
        source_paths = [entry["path"] for entry in build_td.source_manifest()]
        self.assertTrue(any(path.endswith("video_cartoon_luma.v") for path in source_paths))
        self.assertFalse(any(path.endswith("fallback/tb_color.vvp") for path in source_paths))


if __name__ == "__main__":
    unittest.main()
