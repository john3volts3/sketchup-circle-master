# Circle Master

*[Version française](README.fr.md)*

Free SketchUp extension for **3D printing**: exact hole and pin diameters, and smooth cylinders
even after the extrusion.

- **Circle** tool replacing the native one: typed values are a **diameter** by default (`25r` for a
  radius), **48 segments by default** and the last segment count is remembered; inferences, arrow
  keys to lock the axis, click-click or click-drag, as with the native tool.
- **Change the segment count of an extruded cylinder** (`36s`), a hole, a pin or the **rounded
  corner** of a volume — greyed out in *Entity Info*.
- **Resize holes and pins to an exact size**: select the wall, type `5.2` or `+0.2`; both ends
  change, the host face and its materials stay intact. Size and segments together: `5.2;48s`.
- **Broken circles** (cut by a solid operation, exploded or welded) are **rebuilt as native
  circles** while resizing: center inference and *Entity Info* work again.
- Resize and re-segment existing circles and arcs, place **copies** of a circle (Ctrl), repeat the
  previous circle with a **double-click**.
- Decimal point or comma, whatever the Windows settings; one undo step per action.

Tested on **SketchUp 2021 Pro** and **SketchUp Make 2017** (Windows). Does not need SketchUp Pro.
The extension interface is in English.

## Installation

1. Uninstall **Circle Advanced** and **Cylinder Resize** if they are installed (Circle Master
   replaces them and takes over their settings).
2. Download `circle_master.rbz` from the [releases](../../releases/latest).
3. SketchUp → *Extensions → Extension Manager → Install Extension…* → select the `.rbz`.
4. (Recommended) *Window → Preferences → Shortcuts*: assign the **C** key to
   `Extensions/Circle Master/Circle`.

## Quick start

| Goal | How |
|------|-----|
| Draw a Ø 25 circle | **Circle**, click the center, type `25`, Enter |
| Smooth an extruded cylinder | Select one of its end circles, **Circle**, type `64s` — or select its wall, **Cylinder Resize Tool**, type `64s` |
| Hole at the printing clearance | **Cylinder Resize Tool**, click the hole wall, type `5.2` (or `+0.2`) |
| Size and segments at once | `5.2;48s` |

| Input | Effect |
|-------|--------|
| `50` / `50mm` | Diameter (or radius, see *Settings*) |
| `25r` / `r25` | Radius |
| `50d` | Explicit diameter |
| `48s` | Segment count |
| `50;36s` | Size and segments |
| `+5` / `-2.5` / `+r1` | Increment of the diameter / radius |
| `--5` | Same as `+5` (when `+` is taken by a shortcut) |

## Documentation

- User manual: [English](docs/USER_MANUAL_EN.md) · [Français](docs/USER_MANUAL_FR.md)
- Changes: [CHANGELOG.md](CHANGELOG.md)
- Product requirements and functional specification (French): [PRD.md](PRD.md), [FSD.md](FSD.md)

## Origin

Circle Master brings together **Circle Advanced 1.4.0** and **Cylinder Resize 0.3.0**, with the
native-circle reconstruction engine of **Re-Cercle** and **Solid Progress** (same author).

## Development

- Automatic tests (SketchUp closed): `powershell -File tools\tests\run_tests.ps1` (SketchUp 2021,
  then Make 2017); parser cases without SketchUp: `ruby tools/tests/vcb_parser_cases.rb`.
- Reload without restarting SketchUp (Ruby Console): `CircleMaster.reload`.
- Code compatible with Ruby 2.2 (SketchUp 2017): no `&.`, `<<~`, `clamp`, `match?`…
- Build the `.rbz`: zip `circle_master.rb` and `circle_master/`, rename to `.rbz`.

## License

MIT — see [LICENSE](LICENSE).
