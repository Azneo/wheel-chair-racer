# Project Rules

- Work in this existing Godot 4.7 project; do not create a second project.
- Use GDScript, tabs for indentation, and the GL Compatibility renderer.
- Main scene: `scenes/main.tscn`. Track/HUD/camera: `scripts/main.gd`.
- Vehicle: `scripts/wheelchair.gd`, using CharacterBody3D and move_and_slide.
- Use the named InputMap actions: accelerate, brake, steer_left, steer_right, reset.
- Keep the prototype geometric and self-contained. No downloaded models,
  opponents, customization, or complex wheel physics without a new request.
- Preserve user changes; do not edit generated files in `.godot/`.
- Run Godot import and startup checks after changes. Report headless checks
  separately from actual graphical rendering and manual gameplay testing.
- Regression command: Godot `--headless --path . --fixed-fps 60 --script
  res://tests/smoke_test.gd`. See README.md for graphical checks and local setup.