# Seating Profiles

The solver is in [racer_visuals.gd](../scripts/racer_visuals.gd), with chair data
in [seating.tres](../assets/wheelchair/seating.tres) using
[seating_profile.gd](../scripts/seating_profile.gd). Vehicle motion, its collision
shape, and the workshop/follow cameras are unchanged.

## Constraint Order

1. Measure the rider's bind geometry: supported pelvis/thigh skin, limb lengths,
   soles, and hand extents. Shin and foot vertices never determine pelvis height.
2. Search a bounded fore/aft region of the usable seat. For each candidate, fit
   height only from pelvis/thigh support, solve the legs toward fixed ankle
   targets, then reject seat/frame intersections. Unreachable feet abort height
   correction instead of lifting the rider to chase a shin below the seat.
3. With support and feet fixed, search up to 15 degrees of torso recline for
   arm reach through 32 stroke phases and both breathing extremes. Two-bone IK
   preserves lengths and limits flexion to 8-145 degrees; elbow lateral
   displacement is bounded to the equivalent of 45 degrees of abduction.
4. Derive hand offsets from oriented skin geometry. During motor changes, move
   over the armrest on an eased 0.4-second path. Constrain the intermediate hand
   surface against the wheel envelope before solving the arm.
5. Evaluate each elbow candidate from the same bone poses. Search a fixed angular
   grid ordered by proximity to the previous elbow; once the transfer ends,
   relax toward the resting pole. Orient palms toward the wheel or support.

Support fitting happens at initialization, not as an accumulating per-frame
pelvis correction. `fit_conflicts`, `fit_error`, `reach_failures`, and
`constraint_failures` expose incompatible dimensions/targets. Initialization
warns on fit conflicts; do not approve a new profile with those warnings.

These are skeletal constraints, not physical collision response. The unchanged
CharacterBody3D collider handles driving against the world. Skin samples and
authored boxes detect pose intersections; IK selects a pose. No ragdoll, force
feedback, extra rigid bodies, or full-body physics are introduced.

## Integrate Another Chair

1. Prepare a PackedScene with separate rear-wheel MeshInstance3D nodes, centered
   wheel pivots, local X rotation axes, and separate caster/fork nodes. Use
   uniform positive scale and align the wheels with the seat frame. Bake unusual
   wheel rotations into the source mesh; canted axles are not supported here.
2. Duplicate [seating.tres](../assets/wheelchair/seating.tres) under a new name.
   Set `model`, `model_transform`, `rider_scale`, and all wheel/caster/fork paths.
   Paths are relative to the instantiated chair root and must resolve.
3. Set `seat` to the support top-center in Presentation-local coordinates, with
   an orthonormal basis: +Y up, -Z forward, X lateral. Set `seat_size` to usable
   width/depth and `seat_thickness` to the solid cushion thickness. Alternatively,
   provide `seat_mesh` for a dedicated, seat-aligned mesh: its transformed AABB
   supplies top-center, orientation, width and depth. Do not use a combined
   frame/chair mesh for automatic seat bounds.
4. Supply two `foot_supports` (top-center points) and `foot_sizes` (width/depth).
   Every support point and box below is seat-local, in metres, ordered negative-X
   then positive-X. Soles determine ankle offsets. Existing plates must fit the
   shoes. For generated plates, set `generate_footplates=true` and two
   `foot_mounts`; generated sizes expand to cover measured soles plus clearance.
5. Set `back`, two `armrests` if present, and `frame_solids` as conservative
   seat-local AABBs. Optional two `controls` transforms replace motor wrist
   targets: origin is the wrist position, -Z the finger direction, -Y the palm
   normal. Without armrests or controls the motor pose uses a lap-area fallback,
   which requires separate visual approval.
6. Set `handrim_radius` explicitly when known. Zero uses 92% of the wheel radius.
   Wheel bounds determine outer contact planes and axle centers; radius comes
   from scaled mesh bounds. Models whose bounds include unrelated geometry need
   properly separated wheel meshes, not arbitrary solver offsets.
7. Assign the resource to `wheelchair.seating_profile` **before** adding the
   vehicle to the scene tree. The runtime vehicle creates its Presentation in
   `_ready()`. For an isolated preview, assign `RacerVisuals.seating` before
   adding that node instead. No solver source changes are needed.
8. Inspect fit diagnostics, run the seating regression against the new profile,
   then inspect STOCK/motor front, side, rear, driving and repeated transition
   views. The current regression includes asset-specific topology, node and
   conservative wheel-envelope assertions: keep those for the bundled asset
   and add a separate fixture for a different production model.

## Verification: 2026-10-19

Godot 4.7.2, GL Compatibility. All executed suites passed:

| Check | Result |
| --- | --- |
| Focused seating | 52 passed, 0 failed |
| Headless driving smoke | 31 passed |
| Headless race | 79 passed, 0 failed |
| Headless upgrades, including seating | 205 passed |
| Graphical upgrades, native 1920x1080 | 245 passed, Intel Iris Xe |

Regression coverage includes shin exclusion, impossible foot targets without
pelvis lift, sole support footprints, actual motor hand/pad overlap, body/hand
clearance, both arms' continuity, forward/reverse strokes, interrupted motor
changes, invalid metadata, and rotated/translated chair configuration reuse.
The automated lap remains 00:17.235 without wall contact. Save-failure warnings
in the upgrade suite are intentional fixtures; personal saves are isolated.

Final graphical captures: `user://upgrade-menu-32220-1575235-*.png`, in
`%APPDATA%/Godot/app_userdata/WheelChairRacer/`. Front and side views of STOCK
and motor poses, and the driving push view were visually inspected. Earlier
iterations' rear views were also inspected. No human gameplay test was performed.

Focused command, using the Godot executable configured in [README](../README.md):

```powershell
& $godot --headless --path . --fixed-fps 60 --script res://tests/upgrade_test.gd -- --seating-only
```

## Limits

- The bundled rider's rig/bone names and skin are the supported character.
  Another character requires a rig adapter, not just chair metadata.
- Manual hands track the handrim with conservative clearance, not a closed
  finger grip: measured resting hand-to-ring gaps are about 2.1-2.4 cm. Motor
  hand support clearance is about 8 mm. No finger curling or force transfer.
- Seat and leg checks use their skin groups; arm/body acceptance uses sampled
  skin and authored boxes. This is not continuous triangle collision or a
  guarantee against every clothing/self-intersection at every time step.
- Only a transformed configuration of the existing chair was available for
  reuse testing, not a second production chair. Sloped footplates, canted axles,
  arbitrary rigs, asymmetric wheel sizes, and automatic frame segmentation are
  not certified. Vehicle collision and engine mounts still need review for a
  differently sized chair.
- Fit search and runtime CPU skin checks are bounded but not benchmarked for
  multiple riders. No new performance or export claims are made.