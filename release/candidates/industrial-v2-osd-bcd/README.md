# Industrial V2 OSD-BCD timing candidate

Status: `CANDIDATE_ONLY` — not the final seven-feature V2 release.

This candidate is the formal TD display-path build after replacing the HDMI-domain OSD decimal division/modulo logic with BCD increment and bounded dimension conversion.

Build facts:

- Device: `PH1P35MDG324`
- Tang Dynasty: `v6.2.168116`
- Source snapshot: OSD RTL changes were committed as `a0f11cb` after this build; the TD manifest records the pre-commit base plus the modified working-tree source hash.
- Setup WNS/TNS: `+132 ps / 0 ps`
- Hold WNS/TNS: `+20 ps / 0 ps`
- Slices: `18486/21216` (`87.13%`)
- RAMs/DSPs: `43/24`
- Bitstream SHA-256: `b52f929fb845ae681e4bb330eb129254dae3d7941b02e4f285c66a33b55532f2`

The build includes the formal result-CDC and HDMI tracking candidate, but the seven upgrades are not all integrated into the formal top-level. No board download, SC520CS camera acceptance, long-stability run, or final release audit PASS is claimed.
