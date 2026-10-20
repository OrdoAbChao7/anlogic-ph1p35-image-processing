# Industrial V2 I²C counter-width candidate

This is an isolated, rejected candidate for the Industrial V2 G8 audit. It is not the formal downloadable candidate.

- Transform: `scripts/prepare_i2c_counter_width.py`
- Source SHA-256: `da507aae17f1a464566bf741323da8b782ff4d7b46c30e676d9b8ed7d124da58`
- Route QoR: Slice `18295/21216 = 86.23%`, Setup WNS `+107 ps`, Hold WNS `+20 ps`, TNS `0`
- Bitstream SHA-256: `4c85e27006742452c80d7aba475169b95b7ad13572565bc7228514777662c767`
- Decision: rejected because Slice exceeds the `<=85%` resource gate; PHY warnings remain open.

Evidence:

- `docs/experiments/2026-10-19-industrial-v2-g8-i2c-counter-width.md`
- `docs/evidence/industrial-v2-g8-i2c-counter-width-log.txt`
