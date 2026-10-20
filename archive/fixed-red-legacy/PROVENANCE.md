# Legacy fixed-red baseline provenance

These two files are the archived pre-V2 `color_detect_96` smoke-test baseline. Their source is the repository commit [`651f9bca3490649afbe1449802d1f3e8ae8df0bf`](https://github.com/OrdoAbChao7/anlogic-ph1p35-image-processing/commit/651f9bca3490649afbe1449802d1f3e8ae8df0bf), which introduced `fallback/rtl/color_detect_96.v` and `fallback/tb_color_detect_96.v`.

The archived files match the commit contents exactly after normalizing CRLF to LF. Git blob SHA-1 values are `7bf139295d3d58da688688ef9ddda86c8fcd917b` (RTL) and `8cc5c465b839352cb0c8d9fc8ce8df0fcbbe1e0e` (testbench). The archived CRLF files have SHA-256 values `7235ccdcf7da136f18b1f267677ffd3c9cc4c9c9bef0bdf76f4fc8ec74e60a55` and `d4745800365e6f99aebf895929088aa222bb58876440df11e06f51dc3ea4f288` respectively.

This historical testbench checks one four-pixel red sample, area `4`, and horizontal bounds `0..3`; it does not constitute a comprehensive detector contract or hardware evidence. The compiled `.vvp` artifact present in the historical commit is intentionally not archived.
