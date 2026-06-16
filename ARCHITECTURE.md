# System Architecture

This document describes every component in the repository, how data flows between them, and which MATLAB file implements each piece.

---

## High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  INPUT                                                          │
│  Predefined: data/boxes_sample.csv + data/pallet_config.json   │
│  Real-time : simulateBoxDetection → PerceptionBuffer            │
└────────────────────────────┬────────────────────────────────────┘
                             │ acquireBoxData.m
                             ▼
              ┌──────────────────────────┐
              │   Layout Optimizer        │
              │  greedyLayoutHeuristic   │
              │  gaLayoutOptimizer       │◄── Global Opt TB (optional)
              │  saLayoutOptimizer       │
              │  milpLayoutOptimizer     │◄── Optimization TB (optional)
              └──────────┬───────────────┘
                         │ layout table (x, y, z per box)
          ┌──────────────┼──────────────────┐
          ▼              ▼                  ▼
  checkLayout      plotPalletLayout    layoutToObstacles
  Collisions.m     (3-D plot)          .m
                                           │
                                           ▼
                              ┌────────────────────────┐
                              │  Trajectory Planner     │
                              │  rrtPlanner.m           │
                              │  chompSmooth.m          │
                              │  planPickPlaceTrajectory│
                              └────────────┬────────────┘
                                           │ Nx3 waypoints per box
                                           ▼
                              ┌────────────────────────┐
                              │  RTDEInterface.m        │
                              │  mock  → CommandLog     │
                              │  urscript → UR3e/URSim  │
                              └────────────────────────┘
```

---

## Components

### `src/optimization/` — Layout Optimizer

| File | Role |
|---|---|
| `shelfPack.m` | Core 2-D shelf-packing kernel. Places boxes left-to-right, starting a new shelf when the current row overflows. All optimizers call this for final placement. |
| `layoutObjective.m` | Converts a layout table into a scalar cost (`−utilization + penalty × unplaced`). Used as the fitness/objective function by GA and SA. |
| `decodeChromosome.m` | Decodes a continuous `[0,1]^(2N)` vector into a box order + rotation mask, then calls `shelfPack`. Lets continuous optimizers (GA, SA) search over discrete placement decisions. |
| `greedyLayoutHeuristic.m` | Sorts boxes by footprint area (largest first), optionally rotates each for a better fit, and calls `shelfPack`. Zero toolbox dependencies; suitable for real-time mode. |
| `gaLayoutOptimizer.m` | Wraps MATLAB's `ga()`. Encodes solutions as chromosomes via `decodeChromosome`. Requires Global Optimization Toolbox. |
| `saLayoutOptimizer.m` | Wraps MATLAB's `simulannealbnd()`. Same chromosome encoding. Requires Global Optimization Toolbox. |
| `milpLayoutOptimizer.m` | Solves a MILP (via `intlinprog`) that assigns each box to a stacking layer to minimise total stack height, subject to area and weight capacity constraints. Then calls `shelfPack` within each layer. Requires Optimization Toolbox. |
| `checkLayoutCollisions.m` | Validates that all placed boxes lie within the pallet footprint (and max height if given), and that no two same-layer boxes overlap. Returns `isValid` + a human-readable issues cell array. |
| `plotPalletLayout.m` | Renders placed boxes as coloured 3-D cuboids (MATLAB `patch`). A dependency-free stand-in for Sim3D during development. |

**Output format — the layout table:**

| Column | Type | Description |
|---|---|---|
| `id` | string | Box identifier |
| `length`, `width`, `height` | double (mm) | Original box dimensions |
| `weight` | double (kg) | Box weight |
| `placedLength`, `placedWidth` | double (mm) | Footprint after optional rotation |
| `x`, `y`, `z` | double (mm) | Bottom-left-front corner on the pallet |
| `rotated` | logical | Whether the box was rotated 90° |
| `placed` | logical | Whether the box fits on the pallet |

---

### `src/trajectory_planning/` — Motion Planner

| File | Role |
|---|---|
| `rrtPlanner.m` | 3-D RRT using axis-aligned bounding box (AABB) collision checks. Samples the workspace uniformly with configurable goal bias. Pure MATLAB, no toolbox. |
| `chompSmooth.m` | CHOMP-inspired gradient smoother. Resamples an RRT path to a fixed number of waypoints, then iteratively pulls each interior waypoint toward the midpoint of its neighbours (smoothness term) and away from nearby obstacles (repulsion term via numerical gradient). |
| `checkPathCollisionFree.m` | Samples evenly along each segment of a multi-waypoint path and tests against an AABB obstacle array. Used for path validation and for checking the final descent segment in `planPickPlaceTrajectory`. |
| `layoutToObstacles.m` | Converts a layout table (already-placed boxes) into the `struct array(min, max)` obstacle format consumed by the planners. Accepts an optional clearance margin. |
| `planPickPlaceTrajectory.m` | High-level planner: runs RRT from home to an "approach" point above the target, smooths with CHOMP, then checks a short straight descent to the final place position. Returns an `Nx3` waypoint array. |
| `plotTrajectory3D.m` | Renders the waypoint path and AABB obstacles in a 3-D MATLAB plot, with colour-coded start (green circle) and end (red square) markers. |

---

### `src/perception/` — Box Detection & Buffering

| File | Role |
|---|---|
| `simulateBoxDetection.m` | Generates synthetic box descriptors with randomised dimensions and density-derived weights. Stands in for a Computer Vision Toolbox camera pipeline on a real conveyor. Accepts a `Seed` for reproducible tests. |
| `generateBoxID.m` | Returns a random `"BOX-NNNNN"` identifier string. Represents a QR/barcode read in a real deployment. |
| `PerceptionBuffer.m` | Handle class. Accumulates detected box rows until `ReadyThreshold` boxes arrive or `MaxWaitSeconds` elapses, then `flush()` returns the batch for optimization. Implements the "buffering in a temporary holding area" strategy from the project brief. |

---

### `src/control/` — Integration & Robot Interface

| File | Role |
|---|---|
| `acquireBoxData.m` | Wraps both acquisition modes behind one function call. `"predefined"` reads `data/boxes_sample.csv`; `"realtime"` fills a `PerceptionBuffer` via `simulateBoxDetection`. |
| `RTDEInterface.m` | Handle class. `Mode = "mock"` records all motion commands to `CommandLog` (no network, safe for tests/CI). `Mode = "urscript"` opens a TCP connection to port 30002 and sends `movel`/`movej` URScript strings. Provides `connect`, `disconnect`, `moveLinear`, `moveJoint`, `sendBoxPlacement`, `getActualTCPPose`. |
| `runPalletizingControlLoop.m` | **Main entry point.** Calls every other module in the correct order: acquire → optimise → validate → visualise → plan trajectories per box (in layer/shelf order) → send to robot. Returns a `results` struct containing the layout, trajectories, command log, and figure handles. |

---

### `data/`

| File | Contents |
|---|---|
| `boxes_sample.csv` | 10 boxes, columns: `id, length, width, height, weight` (mm / kg). Used by `acquireBoxData` in `"predefined"` mode. |
| `pallet_config.json` | EUR/EPAL pallet: 1200 × 800 mm footprint, 1200 mm max height, 1000 kg max weight. Loaded by `runPalletizingControlLoop`. |

---

### `models/`

Placeholder for Simulink (`.slx`) and Sim3D scene files. See `models/README.md` for setup instructions. The MATLAB scripts in `src/` and `scripts/` run entirely without these models; they are needed only for full Sim3D visualisation and for deploying via the Simulink RTDE block.

---

### `tests/`

MATLAB unit tests (`matlab.unittest`). Each test class maps to one or two source files:

| Test file | Covers |
|---|---|
| `tShelfPack.m` | `shelfPack.m` |
| `tLayoutObjective.m` | `layoutObjective.m` |
| `tCheckLayoutCollisions.m` | `checkLayoutCollisions.m` |
| `tGreedyOptimizer.m` | `greedyLayoutHeuristic.m`, `decodeChromosome.m` |
| `tRrtPlanner.m` | `rrtPlanner.m`, `checkPathCollisionFree.m`, `layoutToObstacles.m` |
| `tChompSmooth.m` | `chompSmooth.m` |
| `tPerceptionBuffer.m` | `PerceptionBuffer.m`, `simulateBoxDetection.m`, `generateBoxID.m` |
| `tIntegration.m` | Full `runPalletizingControlLoop` pipeline (smoke test) |

---

### `scripts/`

| Script | What it does |
|---|---|
| `run_demo.m` | Loads predefined boxes, runs greedy optimizer, plots layout + first trajectory |
| `run_optimizer_comparison.m` | Runs all four optimizers on the same dataset and prints a utilisation + time comparison table |
| `run_realtime_demo.m` | Simulates a conveyor feed, buffers boxes with `PerceptionBuffer`, runs greedy optimizer |
| `run_all_tests.m` | Runs the full `tests/` suite and prints a results table |

---

## Sim-to-Real Path (URSim → UR3e)

1. Run the full pipeline in `"mock"` RTDE mode and verify `results.layout` and trajectories look correct.
2. Start URSim and note its IP (default `192.168.56.101`).
3. Switch to `RTDEMode = "urscript"`, set `RTDEHost` to the URSim IP, and re-run. Watch the virtual robot execute each placement.
4. On the physical UR3e, set `RTDEHost` to the robot's IP, verify coordinate frame calibration (pallet origin, approach height), and run.

No Simulink model changes are needed between steps 3 and 4 — only the IP address changes.
