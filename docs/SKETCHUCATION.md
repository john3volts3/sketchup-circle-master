# Circle Master — SketchUcation Plugin Page Content

Text for the SketchUcation PluginStore listing: copy each section into the matching field of the Dev Tool.

> **2026-10-26**: GitHub repository made public (whole history checked first: no personal data). Images made (`docs/images/`, put together by `tools/demo/`). PluginStore entry `Circle_Master` created (Dev Tools > Edit > green **+**) and filled — Files: `Circle_Master.rbz` (1.0.0, the asset of the GitHub release), icon `Circle_Master.png` (54 px), article images `cm_segments.png`, `cm_settings.png`, `cm_resize.png` (690 px wide); Basic Info; Overview; Start; Documentation; Release Notes. Saved as a draft and checked by reloading the editor; **not published** (power button left to the author). Author Info left empty (personal data). No YouTube video yet.
>
> **2026-10-27**: version 1.0.1 (fix: a neighboring circle touching the rebuilt one). Draft updated: `Circle_Master.rbz` replaced with the asset of the GitHub release `v1.0.1` (Files > Remove & Update, then upload); Basic Info version 1.0.1; Overview test results 45/45 and 43/43; Documentation, limitation of circles that touch; Release Notes v1.0.1 above v1.0.0. Each tab saved and checked by reloading the editor; still **not published**.
>
> **2026-10-27**: published by the author. Compatibility boxes **SU 2017 to SU 2027** ticked by the author after a theoretical check of the versions (see `FSD.md`, "Compatibilité des versions"); saved state checked by reloading the editor.

---

## Metadata (Basic Info)

- **PluginStore identifier:** `Circle_Master` (page `https://sketchucation.com/pluginstore?pln=Circle_Master` once published)
- **Plugin name:** Circle Master
- **Version:** 1.0.1
- **Short description (255 chars max):** Circle tool that keeps your segment count from one session to the next and takes a diameter or a radius. Change the segments and size of circles inside volumes: cylinders, holes, pins, rounded corners, even after booleans. Free.
- **Usage:** Extensions > Circle Master (menu and toolbar)
- **Compatibility:** SU 2017, 2018, 2019, 2020, 2021/22, 2023, 2024, 2025, 2026, 2027 — tested with SketchUp Make 2017 and SketchUp Pro 2021 on Windows; the other versions checked against the Ruby API release notes, not tested; macOS not tested
- **Dependencies:** None
- **License:** Free (MIT)
- **Support Link (More info button):** https://github.com/john3volts3/sketchup-circle-master
- **YouTube link (Tutorial):** none yet
- **Categories:** Drawing, Modification, 3D Printing (as offered by the form)
- **Icon:** `Circle_Master.png`, 54 × 54 px (made by `tools/demo/make_images.py`)
- **Screenshots:** `docs/images/cm_segments.png` (main), `cm_settings.png`, `cm_resize.png`; copies 690 px wide for the page

---

## Overview (Markdown)

**Circles the way you want them: your segment count in every session, a diameter or a radius, and circles you can still change once they are part of a volume.**

{img}cm_segments.png{/img}

Circle Master is a free Circle tool and a set of commands made for **3D printing**, where the number of segments of a circle ends up as facets on the print, and where a hole or a pin must have an exact diameter.

### Your segment count, every session

SketchUp's own Circle tool goes back to **24 segments** each time SketchUp starts. Circle Master starts with **yours** — 48 by default, any count from 3 to 999 — and **keeps it from one session to the next**. Type `64s` once: it is still 64 tomorrow, in every command of the extension.

### A diameter or a radius

Type `25` and you get a **Ø 25** circle: values are diameters by default, the way parts are dimensioned. A radius is always one letter away (`12.5r`), and if you prefer radii, switch the default in **Settings**: `12.5` is then a radius and `25d` a diameter. The same setting applies to every command.

{img}cm_settings.png{/img}

### Change circles that are part of a volume

Once a circle has been extruded, Entity Info greys out its segment count. Circle Master changes it anyway, and rebuilds the volume with **native SketchUp circles** (center inference and Entity Info keep working):

- **Cylinders, holes and pins**: select one end circle, type `64s` — both ends get 64 segments.
- **Rounded corners** of a volume, outer or inner: select one of its arcs, type `16s` — the curved wall is rebuilt, the neighboring faces stay tangent.
- **Exact sizes**: with the Cylinder Resize Tool, click the wall of a hole or a pin and type `5.2`, `+0.2` or `5.2;48s` (size and segments at once). Both ends change; the face around keeps its edges and materials.
- **Broken circles** (cut by solid tools, exploded or welded) are rebuilt as native circles while resizing.

{img}cm_resize.png{/img}

### Features

- **Circle** tool replacing the native one: diameter input, your segment count, inferences, arrow keys to lock the axis, click-click or click-drag; resizes and re-segments existing circles and arcs; copies of a circle (Ctrl); repeat the previous circle (double-click).
- **Resize Cylinders…** (dialog) and **Cylinder Resize Tool** (interactive): several holes or pins at once, absolute size, increment (`+0.2`, `-0.1`, `+r0.5`) and segment count; truncated cones kept or made straight.
- **Settings…**: default segment count, diameter or radius input.
- Decimal point or comma, whatever the Windows settings; one undo step per action.
- Pure Ruby, no dependencies; does not need SketchUp Pro.

### Compatibility

| SketchUp | Status |
|---|---|
| Pro 2021 (tested with 21.0.391) | Automatic test battery: 45/45 |
| Make 2017 (tested with 17.2.2555) | Automatic test battery: 43/43 (2 cases need SketchUp 2020.1+: a circle that cannot be rebuilt is left as edges instead of being welded) |

Windows. Other versions from 2017 on should work but are not tested; macOS not tested. SketchUp Make is licensed by Trimble for non-commercial use only. The interface of the extension is in English.

### Installation

1. Download `Circle_Master.rbz`
2. In SketchUp: **Extensions > Extension Manager > Install Extension** (SketchUp 2017: **Window > Extension Manager**)
3. Select the `.rbz` file
4. The menu and the toolbar appear under **Extensions > Circle Master**
5. Recommended: **Window > Preferences > Shortcuts**, assign the **C** key to `Extensions/Circle Master/Circle`

### Source and user manual

On GitHub: https://github.com/john3volts3/sketchup-circle-master — user manual in English (`docs/USER_MANUAL_EN.md`) and French (`docs/USER_MANUAL_FR.md`).

### Credits

Circle Master brings together two earlier extensions of the same author, Circle Advanced and Cylinder Resize, with the native-circle reconstruction engine of Re-Cercle and Solid Progress. Free software, MIT License.

---

## Start (Markdown)

1. Click **Circle** (toolbar or *Extensions > Circle Master*), click the center, type `25`, Enter: a Ø 25 circle with 48 segments.
2. Want another segment count? Type `64s` while drawing, or set it in **Settings…**: it is kept for the next sessions.
3. Smooth an extruded cylinder or a hole: select one of its end circles, click **Circle**, type `64s`, Enter.
4. Smooth a rounded corner: select one of its arcs, click **Circle**, type `16s`, Enter.
5. Hole at the printing clearance: **Cylinder Resize Tool**, click the wall of the hole, type `5.2` (or `+0.2`), Enter.

---

## Documentation (Markdown)

Full user manual on GitHub: [English](https://github.com/john3volts3/sketchup-circle-master/blob/master/docs/USER_MANUAL_EN.md), [French](https://github.com/john3volts3/sketchup-circle-master/blob/master/docs/USER_MANUAL_FR.md).

### Commands

| Command | What it does |
|---|---|
| **Circle** | Draws circles (diameter input, your segment count); with circles or arcs selected, changes their size or segment count, including the end circle of a cylinder and the arcs of a rounded corner |
| **Resize Cylinders…** | Dialog: resizes the cylinders whose side wall is selected |
| **Cylinder Resize Tool** | The same, interactively: click a cylinder wall, type the new size |
| **Settings…** | Default segment count, diameter or radius input, coordinate mode |

### What you can type (Measurements box)

| Input | Meaning |
|---|---|
| `50` | Diameter 50 (radius if the setting says so) |
| `25r` or `r25` | Radius 25 |
| `50d` or `d50` | Diameter 50 |
| `48s` or `s48` | 48 segments (3 to 999) |
| `50;36s` | Diameter 50 and 36 segments |
| `+5`, `-2.5` | Diameter increment, from each circle's own size |
| `+r1` | Radius increment |
| `--5` | Same as `+5`, when `+` is taken by a keyboard shortcut |

Lengths use the model units; a unit may be typed (`50mm`). Decimal point or comma both work.

### Which command for what?

| You want to… | Use |
|---|---|
| Draw circles with an exact diameter and many segments | **Circle** |
| Change the diameter of a flat circle or arc | **Circle**, circle selected |
| Change the segment count of a cylinder, a hole or a rounded corner | **Circle** (end circle or arc selected) or the cylinder commands (wall selected) |
| Bring a whole hole or pin to an exact diameter (both ends) | **Resize Cylinders…** or **Cylinder Resize Tool** |
| Repair a hole broken by a solid operation while resizing it | the cylinder commands |

### Limitations

- Changing the segment count recreates the neighboring faces: material, tag and orientation are kept, a texture position and attributes are lost.
- Refused, with the reason and nothing changed: polygons, a line attached in the middle of a circle, pointed cones, oblique cylinders, stacked cylinders, rounded corners with an oblique or cut wall.
- An arc whose segments would be shorter than SketchUp's tolerance (0.001″ ≈ 0.025 mm) cannot be drawn, even by the native tools.
- Circles that touch each other (tangent holes): when a vertex of the rebuilt circle falls closer than 0.001″ to the other one, SketchUp joins them and the change is refused, nothing changed. A gap of 0.1 mm between them is enough.
- Inside a component, every copy is modified.

### Troubleshooting

| Problem | Solution |
|---|---|
| Toolbar not visible | *View > Toolbars > Circle Master* |
| "… not supported (…)" | Nothing was changed; the reason tells which condition is not met |
| "… could not be rebuilt, nothing was changed" | The final check failed and everything was undone; please report the case on GitHub with a screenshot |
| Error on load | *Window > Ruby Console*: copy the message and report it on GitHub |

---

## Release Notes

**v1.0.1** (2026-10-27)
- Fixed: a new segment count on a rounded corner, a cylinder, a hole or a pin was refused when another circle touched it (two tangent holes, or a hole tangent to the extension of a rounded corner); nothing was changed, the model was never damaged

**v1.0.0** (2026-10-26)
- First public version: Circle tool (diameter input, segment count kept between sessions), segment count and size of circles inside volumes (cylinders, holes, pins, rounded corners), Cylinder Resize Tool and Resize Cylinders dialog, Settings
- Broken circles rebuilt as native circles while resizing
- Decimal point or comma in every input
