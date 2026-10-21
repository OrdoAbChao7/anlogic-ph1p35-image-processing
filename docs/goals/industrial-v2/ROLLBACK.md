# Industrial Vision V2 Rollback

## Stable candidates

- `BASELINE_V1`: V1 freeze commit `256d99c1d0dc4dbae2ace8d0ff3a97f504d514c9`, Bitstream SHA-256 `b483a1ffc30d0b7ae9e8ebef4f31f617d33a53d6784ded8007d5443c51ad80ef`.
- `LAST_GOOD_V2`: unset until a V2 candidate passes the agreed automated gate and is archived with a manifest.
- `EXPERIMENTAL`: `goal/industrial-v2-advanced` current HEAD.

## Recovery rules

1. Do not overwrite the V1 freeze directory.
2. If a V2 test, TD build or hardware observation regresses, retain logs and first failure, then return the active candidate to the last known good commit or V1 baseline.
3. Never use `git reset --hard` or `git clean -fd` in a user workspace.
4. A new Bitstream gets a new candidate directory, manifest and SHA-256; it does not replace an older candidate.
