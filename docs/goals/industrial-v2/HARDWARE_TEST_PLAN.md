# Industrial Vision V2 Hardware Test Plan

Hardware status is `NOT_RUN` until the board, SC520CS module, HDMI display and download path are present and recorded.

1. Bind commit, source manifest, Bitstream SHA-256, TD version and board/camera/display revisions.
2. Record power, cabling, lens distance, ROI, illumination, target and display mode.
3. Test cold start, download, hot reset and re-download three times before any long run.
4. Exercise Original/Sobel/Cartoon, mode single-click, OSD, empty scene, standard target, out-of-tolerance target, ROI boundary, motion, tracking, light changes and sort event.
5. Record actual camera frame rate, HDMI refresh, internal `PROC/VIDEO` latency and physical `E2E` only with an appropriate instrument.
6. For sorting, use a virtual/board-observable event before connecting an isolated external driver; never drive a power load directly from FPGA IO.
7. Record raw video/photos/logs and the exact failure/recovery path. A short display observation is not a long-stability pass.
