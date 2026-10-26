# Changelog

## 1.0.0 — 2026-10-26

First version: brings together **Circle Advanced 1.4.0** and **Cylinder Resize 0.3.0** in one
extension, *Extensions → Circle Master* and the **Circle Master** toolbar (Circle, Resize
Cylinders…, Cylinder Resize Tool, Settings…).

- Every function of both extensions, with one input parser and one diameter / radius setting for
  all commands (Cylinder Resize Tool follows it too).
- Single native-circle reconstruction engine (from Re-Cercle and Solid Progress), compared with the
  three engines it replaces on the same geometry: same results; broken circles with extra split
  points are now rebuilt; about 5 times faster on a plate with many holes.
- New: segment count in the cylinder commands (`36s`, `15;36s`, `+0.2;48s`).
- New: decimal point or comma in every input, whatever the Windows settings.
- Fixed: more segments on an outer rounded corner of a volume was refused (Circle Advanced 1.4.0).
- Fixed: very small broken circles (1 mm, 48 segments) are rebuilt as native circles.
- Settings window resizable, its size remembered.
- Settings of Circle Advanced and Cylinder Resize taken over until changed.
- Automatic test battery: SketchUp 2021 Pro and SketchUp Make 2017 (Windows).
