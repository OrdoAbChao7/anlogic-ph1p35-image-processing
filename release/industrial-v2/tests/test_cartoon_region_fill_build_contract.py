"""Build-entry contract for an isolated cartoon candidate TD run."""

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "build_industrial_td.py"
spec = importlib.util.spec_from_file_location("build_industrial_td", SCRIPT)
build_td = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = build_td
spec.loader.exec_module(build_td)


class CartoonRegionFillBuildContractTests(unittest.TestCase):
    def test_default_build_stays_on_current_region_fill(self):
        args = build_td.parse_args([])
        self.assertEqual(
            Path(args.video_rtl).resolve(),
            (ROOT / "fallback" / "rtl" / "video" / "video_cartoon_region_fill.v").resolve(),
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

    def test_candidate_build_rejects_default_output_paths(self):
        original = (
            build_td.TD_EXE,
            build_td.FLOW_TCL,
            build_td.ORIG_RUNS,
            build_td.RELEASE_DIR,
            build_td.TRACKED_VIDEO,
            build_td.WORK_PROJECT,
            build_td.WORK_RUNS,
        )
        try:
            with self.assertRaises(ValueError):
                build_td.configure(
                    build_td.parse_args(
                        ["--video-rtl", "work/rtl/video_cartoon_region_fill.v"]
                    )
                )
        finally:
            (
                build_td.TD_EXE,
                build_td.FLOW_TCL,
                build_td.ORIG_RUNS,
                build_td.RELEASE_DIR,
                build_td.TRACKED_VIDEO,
                build_td.WORK_PROJECT,
                build_td.WORK_RUNS,
            ) = original

    def test_staging_rejects_user_owned_vvp(self):
        with tempfile.TemporaryDirectory() as tmp:
            staging = Path(tmp) / "staging"
            staging.mkdir()
            (staging / "tb_color.vvp").write_bytes(b"user-owned")
            with self.assertRaises(RuntimeError):
                build_td.assert_no_user_owned_artifacts(staging)

    def test_manifest_only_rejects_user_owned_vvp_in_release(self):
        with tempfile.TemporaryDirectory() as tmp:
            release = Path(tmp) / "release"
            release.mkdir()
            (release / "tb_color.vvp").write_bytes(b"user-owned")
            original_release = build_td.RELEASE_DIR
            try:
                build_td.RELEASE_DIR = release
                with self.assertRaises(RuntimeError):
                    build_td.write_existing_release_manifest()
            finally:
                build_td.RELEASE_DIR = original_release

    def test_source_manifest_never_includes_user_owned_vvp(self):
        source_paths = [entry["path"] for entry in build_td.source_manifest()]
        self.assertTrue(any(path.endswith("video_cartoon_region_fill.v") for path in source_paths))
        self.assertFalse(any(path.endswith("fallback/tb_color.vvp") for path in source_paths))


if __name__ == "__main__":
    unittest.main()
