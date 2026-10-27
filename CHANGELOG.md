# Changelog

## 1.1.0 — 2026-10-27

- New **Resize Cylinders…** window (replaces the former input box):
  - **Segments** field, filled with the current segment count;
  - **Step** buttons, **+0.05 to +0.3** and **-0.05 to -0.3** (model units): one click adds the
    step to each selected cylinder from its own size and closes the window — handy for the fits
    of 3D printed parts. On the diameter or the radius, as chosen in *Mode*;
  - only the fields you change are applied (confirming the displayed size, rounded, no longer
    shifts it slightly); the displayed value follows the mode (diameter or radius);
  - errors are shown in the window, which stays open.
- Automatic test battery: SketchUp 2021 Pro 46/46, SketchUp Make 2017 44/44.

## 1.0.1 — 2026-10-27

- Fixed: a new segment count on a rounded corner was refused ("The rounded corner could not be
  rebuilt, nothing was changed") when a hole of the same face touched the extension of the corner
  circle, or came closer to it than 0.5 % of its radius.
- Fixed: the same with a cylinder, a hole or a pin touching another one, for example two tangent
  holes ("The cylinder could not be rebuilt, nothing was changed").
- Cause: an edge of the neighboring circle was counted with the rebuilt circle, so the final check
  refused and everything was undone. The model was never damaged.

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
