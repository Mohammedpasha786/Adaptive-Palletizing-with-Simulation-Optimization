# Adaptive Palletizing with Simulation Optimization

A simulation-driven, flexible robotic palletizing system for a **Universal Robots UR3 e-series** cobot. The system computes pallet layouts on the fly for boxes of varying sizes and weights, plans collision-free robot trajectories, validates everything in **Sim3D** (or a built-in 3D MATLAB plot for quick inspection), and deploys to hardware or **URSim** via a **URScript/RTDE** interface — all driven by **MATLAB** and **Simulink**.

## What is in this repository

```
adaptive-palletizing/
│
├── README.md                          ← you are here
├── CONTRIBUTING.md
├── CHANGELOG.md
├── LICENSE
│
├── docs/
│   ├── PROJECT_PROPOSAL.md            ← full project brief
│   ├── ARCHITECTURE.md                ← system design + data-flow diagram
│   └── ROADMAP.md                     ← milestone checklist (with status)
│
├── data/
│   ├── boxes_sample.csv               ← 10-box predefined dataset (EUR pallet)
│   └── pallet_config.json             ← EUR pallet dimensions + constraints
│
├── src/
│   ├── optimization/                  ← layout algorithms
│   │   ├── shelfPack.m                  shelf / next-fit 2D packing kernel
│   │   ├── layoutObjective.m            scalar cost (utilization + penalties)
│   │   ├── decodeChromosome.m           continuous → order+rotation decoder
│   │   ├── greedyLayoutHeuristic.m      rule-based (no toolbox needed)
│   │   ├── gaLayoutOptimizer.m          Genetic Algorithm  (Global Opt TB)
│   │   ├── saLayoutOptimizer.m          Simulated Annealing (Global Opt TB)
│   │   ├── milpLayoutOptimizer.m        MILP layer assignment (Opt TB)
│   │   ├── checkLayoutCollisions.m      collision / bounds validator
│   │   └── plotPalletLayout.m           3-D box visualizer (no Sim3D needed)
│   │
│   ├── trajectory_planning/           ← motion planning
│   │   ├── rrtPlanner.m                 3-D RRT (pure MATLAB)
│   │   ├── chompSmooth.m                CHOMP-inspired gradient smoother
│   │   ├── checkPathCollisionFree.m     edge-by-edge AABB collision check
│   │   ├── layoutToObstacles.m          layout table → AABB obstacle array
│   │   ├── planPickPlaceTrajectory.m    home → approach → place planner
│   │   └── plotTrajectory3D.m           trajectory + obstacle visualizer
│   │
│   ├── perception/                    ← box detection / buffering
│   │   ├── simulateBoxDetection.m       synthetic conveyor-feed generator
│   │   ├── generateBoxID.m              random QR / barcode ID generator
│   │   └── PerceptionBuffer.m           real-time accumulation buffer (class)
│   │
│   └── control/                       ← integration + robot interface
│       ├── acquireBoxData.m             predefined or real-time box input
│       ├── RTDEInterface.m              mock / URScript robot driver (class)
│       └── runPalletizingControlLoop.m  ← MAIN ENTRY POINT
│
├── models/
│   └── README.md                      ← Sim3D / Simulink model instructions
│
├── tests/
│   ├── tShelfPack.m                   unit tests for shelfPack
│   ├── tLayoutObjective.m             unit tests for layoutObjective
│   ├── tCheckLayoutCollisions.m       unit tests for collision checker
│   ├── tGreedyOptimizer.m             unit tests for greedy heuristic
│   ├── tRrtPlanner.m                  unit tests for RRT planner
│   ├── tChompSmooth.m                 unit tests for CHOMP smoother
│   ├── tPerceptionBuffer.m            unit tests for PerceptionBuffer
│   └── tIntegration.m                 end-to-end pipeline smoke test
│
├── scripts/
│   ├── run_demo.m                     ← quick interactive demo (greedy)
│   ├── run_optimizer_comparison.m     compare greedy / GA / SA / MILP
│   ├── run_realtime_demo.m            real-time (conveyor) mode demo
│   └── run_all_tests.m                run the full test suite
│
└── .github/
    ├── workflows/
    │   ├── matlab-ci.yml              CI: run tests on push / PR
    │   └── matlab-lint.yml            CI: Code Analyzer on src/
    ├── ISSUE_TEMPLATE/
    │   ├── bug_report.md
    │   └── feature_request.md
    └── PULL_REQUEST_TEMPLATE.md
```

---

## Quick start (5 minutes, no toolboxes required)

```matlab
% 1. Add all source folders to path
addpath(genpath('src'));
addpath(genpath('data'));

% 2. Run the full pipeline with defaults
%    (greedy optimizer, mock RTDE, predefined box data, 3-D plots)
results = runPalletizingControlLoop();

% 3. Inspect the layout table
disp(results.layout)

% 4. See what commands would have been sent to the robot
disp(results.rtdeCommandLog)
```

Or run the one-shot demo script:

```matlab
run scripts/run_demo.m
```

---

## Running with different optimizers

```matlab
% Greedy heuristic (default, no toolbox)
results = runPalletizingControlLoop('OptimizerType', 'greedy');

% Genetic Algorithm (requires Global Optimization Toolbox)
results = runPalletizingControlLoop('OptimizerType', 'ga', ...
    'OptimizerOptions', struct('MaxGenerations', 150));

% Simulated Annealing (requires Global Optimization Toolbox)
results = runPalletizingControlLoop('OptimizerType', 'sa');

% MILP (requires Optimization Toolbox)
results = runPalletizingControlLoop('OptimizerType', 'milp', ...
    'OptimizerOptions', struct('MaxLayers', 3));
```

---

## Real-time (conveyor) mode

```matlab
results = runPalletizingControlLoop('Mode', 'realtime', 'NumBoxes', 10, 'Seed', 42);
```

---

## Connecting to URSim or a physical UR3e

```matlab
results = runPalletizingControlLoop( ...
    'RTDEMode', 'urscript', ...
    'RTDEHost', '192.168.56.101', ...   % URSim default IP
    'RTDEPort', 30002, ...
    'Visualize', false);
```

See `src/control/RTDEInterface.m` for connection details and `docs/PROJECT_PROPOSAL.md` Step 6 for sim-to-real calibration notes.

---

## Running the tests

```matlab
run scripts/run_all_tests.m
% or directly:
results = runtests('tests');
table(results)
```

---

## Requirements

| Requirement | Notes |
|---|---|
| MATLAB R2023b+ | Core language; all base features work without add-ons |
| Simulink + Simulink 3D Animation | For `models/` Sim3D visualisation (optional for scripts) |
| Robotics System Toolbox | For full UR3 kinematic model in Simulink models |
| Global Optimization Toolbox | For `gaLayoutOptimizer` and `saLayoutOptimizer` |
| Optimization Toolbox | For `milpLayoutOptimizer` |
| Computer Vision Toolbox | For real camera-based box detection (optional) |
| Predictive Maintenance Toolbox | For the maintenance stretch goal (optional) |
| URSim / UR e-series robot | For `RTDEMode = "urscript"` (optional) |

The greedy heuristic, RRT planner, CHOMP smoother, perception buffer, RTDE mock mode, all visualisations, and all unit tests run on **base MATLAB only**.

---

## Documentation

| File | Contents |
|---|---|
| `docs/PROJECT_PROPOSAL.md` | Full project brief: motivation, steps 1-6, variations, stretch goals |
| `docs/ARCHITECTURE.md` | System components, data-flow diagram, folder map |
| `docs/ROADMAP.md` | Step-by-step milestone checklist with current status |
| `CONTRIBUTING.md` | Branch naming, code style, test requirements, PR process |
| `CHANGELOG.md` | Version history |

---

## References

- Lee J-D et al. *Intelligent Robotic Palletizer System*. Applied Sciences 2021; 11(24):12159. https://doi.org/10.3390/app112412159
- MathWorks: Optimization Toolbox, Global Optimization Toolbox, Simulink 3D Animation, Robotics System Toolbox documentation
- Universal Robots: URSim setup guide, RTDE Connectivity Interface guide
- MathWorks Example: *Palletize Boxes Using Cobot with Simulink 3D Animation*

