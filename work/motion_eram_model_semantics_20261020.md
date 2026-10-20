# Motion ERAM primitive-model semantics probe

| Item | Frozen value |
|---|---|
| Question | Does the existing `USE_PH1P_HISTORY_ERAM=1` branch preserve the inferred-memory read-before-write and invalid-frame history-commit behavior when simulated with the actual TD PH1P ERAM model? |
| Evidence | Latest full Gate maps `u_motion_diff_160` to 2,400 DRAM LUT and 0 ERAM; the feature-spine instance leaves the ERAM parameter at default 0. Existing equivalence TB has no recorded run and its `MOTION_ERAM_SIMULATION` branch substitutes a plain async-read array. |
| Single variable | Simulation model only: compile the unchanged baseline-vs-ERAM RTL and existing W=4, H=3 equivalence TB against TD's `ph1p_logic_eram.v`; no RTL, parameter, stimulus, or build-setting edit. |
| Fixed inputs | RTL SHA-256 `f3f880cb5265fb1309dcab5a9d686dbbed766fa4250b4e24e936f4c089f66976`; TB SHA-256 `e358380373e3c4453a456c556c84895115f757ad402db4c4f39eeb88bc01b4fa`; TD ERAM model SHA-256 `70d89b70bdd51812ad86b91e88526b4604ebb117516efda5af976fcddb2e69af`; Icarus 14.0; testbench's fixed stimuli. |
| Required semantics | First frame establishes history; same-address read-before-write; partial invalid frame still commits its two samples; next complete frame reuses that frame ID and detects exactly those two changed coordinates; subsequent frame observes refreshed history. No reset of the memory array is introduced. |
| Cheapest check | One Icarus compile/run using the vendor model and existing testbench, with outputs sent to an isolated temporary path. This checks only the model/testbench contract, not PH1P silicon timing. |
| Decision rule | If the protected vendor model cannot be compiled or any output differs, stop: no TD mapping trial. If it passes, record remaining untested frame-gap/missing-start cases and only then decide whether one isolated module Gate mapping is justified. |
| Budget | One compile/run attempt; zero module synthesis, zero full-engineering builds, zero Place/Route/Bitgen. |

## Result

**Stopped before simulation; macro semantics remain unjudged.** The one Icarus compile attempt rejected the TD PH1P ERAM simulation source at `ph1p_logic_eram.v:115`, the start of its `` `pragma protect`` encrypted body, and printed `I give up.` The saved `compile.log` is 97 bytes. No `.vvp` or `simulation.log` was produced, so the testbench never ran; the numeric compiler exit code was not separately captured. `vlog`/`vsim` are unavailable on the current command path. This is a simulator/model compatibility blocker, not evidence that the candidate RTL is equivalent or inequivalent. Per the card, stop here: no alternate simulator retry, module mapping, or full build. Raw evidence: `work/motion_eram_model_semantics_20261020/compile.log`.
