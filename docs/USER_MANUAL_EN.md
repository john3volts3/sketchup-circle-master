# Circle Master — User Manual

*[Version française](USER_MANUAL_FR.md)*

Version 1.1.0

## 1. Overview

**Circle Master** is a free SketchUp extension for people who model parts to **3D print**. It
does two things SketchUp does not do on its own:

- **change the segment count of a cylinder that is already extruded** (fewer visible facets
  on the print), which *Entity Info* only allows for a flat circle;
- **bring a hole or a pin to an exact diameter** (printing clearance), even when a solid
  operation has broken its circles.

It has four commands, in the *Extensions → Circle Master* menu and the **Circle Master**
toolbar:

| Command | What it does |
|---------|--------------|
| **Circle** | Replaces the native Circle tool: diameter input, 48 segments by default and remembered; also resizes existing circles and arcs and changes their segment count, including the end circle of a cylinder and the rounded corner of a volume |
| **Resize Cylinders…** | Dialog: resizes the cylinders whose side wall is selected (diameter, radius, increment, segment count, one-click steps from -0.3 to +0.3) |
| **Cylinder Resize Tool** | The same, interactively: click a cylinder wall, type the new size |
| **Settings…** | Default segment count, diameter or radius input, coordinate mode |

The result is always made of **native SketchUp circles**: center inference works, and *Entity
Info* shows the radius and the segment count.

Circle Master brings together two earlier extensions of the same author, **Circle Advanced
1.4.0** and **Cylinder Resize 0.3.0**, with a common reconstruction engine (from Re-Cercle and
Solid Progress).

## 2. Installation

1. If **Circle Advanced** or **Cylinder Resize** is installed, uninstall it first
   (*Extensions → Extension Manager*): otherwise their commands would appear twice. Their
   settings (segment count, diameter or radius) are taken over by Circle Master.
2. Get the `circle_master.rbz` file (GitHub releases).
3. In SketchUp: *Extensions → Extension Manager → Install Extension…*, select the file and accept
   the warning.

The **Circle Master** toolbar appears (otherwise: *View → Toolbars*).

### Replacing the native Circle tool (C key)

1. *Window → Preferences → Shortcuts*.
2. Type `Circle Master` in the filter.
3. Select `Extensions/Circle Master/Circle`, type `C` in *Add Shortcut*, click **+**.
4. Confirm reassigning the shortcut from the native Circle tool.

## 3. Drawing a circle

1. Activate **Circle** (button, menu or `C` key).
2. **Click** to place the center. The circle follows the orientation of the hovered face,
   otherwise it is horizontal (normal on the blue axis).
3. Set the size by:
   - **clicking** a second time, or
   - **click-dragging and releasing** from the center, or
   - **typing** the value and pressing *Enter*.

The circle's face is created automatically; on an existing face, that face is split. The tool
stays active for the next circle. **Esc** cancels the current circle. The circle is created inside
the group or component being edited.

### Double-click: repeat the previous circle

A **double-click** places a circle with the size and segment count of the previous circle,
centered on the double-clicked point. The previous circle is the last one drawn with the tool, or
the circle selected when the tool was activated, and is remembered for the SketchUp session.

### Preview color

| Color | Meaning |
|-------|---------|
| Red | Circle perpendicular to the red axis |
| Green | Circle perpendicular to the green axis |
| Blue | Horizontal circle (perpendicular to the blue axis) |
| Black | Arbitrary orientation (sloped face) |

A **thick** line means the orientation is locked. While dragging, the dashed center-to-cursor
line turns thick red, green or blue when the cursor runs along an axis.

## 4. Locking the orientation

| Key | Effect |
|-----|--------|
| **→** | Lock to the red axis (press again to unlock) |
| **←** | Lock to the green axis |
| **↑** | Lock to the blue axis |
| **↓** | Lock the current orientation (from the hovered face) |
| **Shift** held | Freeze the orientation while the key is held |

The lock is released after each circle and on Esc.

## 5. Typing values (Measurements box)

The same syntax is used by every command. Lengths use the model units; you may also type a unit
(`50mm`, `2'`). The **decimal point or comma** both work, whatever the settings of Windows
(`7.5` and `7,5`). Several values are separated by `;`.

| Input | Meaning |
|-------|---------|
| `50` | **Diameter** 50 (or radius, if the setting says so, § 9) |
| `25r` or `r25` | **Radius** 25 |
| `50d` or `d50` | Explicit diameter |
| `48s` or `s48` | **48 segments** (3 to 999) |
| `50;36s` | Diameter 50 **and** 36 segments |
| `+5`, `-2.5` | **Increment**: diameter + 5, diameter − 2.5 (existing circle or cylinder) |
| `+r1`, `-0.5r` | Radius increment |
| `--5` | Same as `+5` (when the `+` key is taken by a keyboard shortcut) |

Invalid input beeps and shows a message in the status bar; nothing is changed.

With the **Circle** tool, the effect depends on when you type:

| When | Effect |
|------|--------|
| Before placing the center | A plain number (`36`) sets the number of **sides**, like the native tool. The box shows "Sides". |
| Center placed | The circle is created at the typed size. |
| Right after a circle | The input **modifies that last circle** (size, increment and/or segments). The box shows "Diameter; Segments": `50mm; 48s`. |
| Circles or arcs selected when the tool is activated | The input **modifies the selection** (§ 6). |

A segment count typed while drawing (`48s`) becomes the new default. Modifying the last circle is
no longer possible after another click, another operation or an undo.

## 6. Modifying existing circles and arcs (Circle tool)

1. With the **Select** tool, click the **edge** of a circle or arc (Shift/Ctrl + click to select
   several).
2. Activate **Circle**.
3. The Measurements box shows "Diameter; Segments" with the current size and segment count, e.g.
   `50mm; 48s`.
4. Type the new value and press *Enter*:

| Input | Effect |
|-------|--------|
| `60` | Diameter 60 (all selected curves) |
| `30r` | Radius 30 |
| `+5` / `-2.5` | Each curve grows by 5 / shrinks by 2.5, from its own size |
| `36s` | **36 segments** (an arc itself gets 36 segments, as in *Entity Info*) |
| `60;36s` | Diameter 60 **and** 36 segments |

The circle keeps its center and stays a native circle; its disc, or the hole in a face, follows
with its materials. The default segment count is not changed.

- **Cylinders**: `36s` on an end circle of a cylinder or truncated cone (hole, pin, countersink)
  rebuilds the **whole volume** with 36 segments at both ends — *Entity Info* does not allow it
  (greyed field).
- **Rounded corners of volumes**: `36s` on one of the two arcs of a rounded corner (rounded edge
  of a box, rounded inner corner of an L…) rebuilds the curved wall and both arcs with 36 segments;
  the neighboring faces stay tangent. More or fewer segments, outer or inner corner.

The tool stays in this mode: typing again adjusts; **Ctrl+Z** undoes one input at a time. A
**click** starts a new circle and **Esc** leaves the mode (the selection is cleared).

### Placing copies of a selected circle (Ctrl)

1. Select a circle and activate the tool.
2. Press and release **Ctrl** alone (or type `=` and *Enter*): **copy mode**; the status bar shows
   "Copy: …".
3. Each **click** places a circle of that size and segment count. Typing a value (`30`, `+2`,
   `36s`) changes the circle just placed and the next ones.
4. **Ctrl** again or **Esc**: back to normal drawing.

### Good to know

- Only the **edge** counts: a disc face selected alone is not enough.
- Resizing only the end circle of a cylinder with the Circle tool turns it into a truncated cone:
  to resize a **whole cylinder**, use the cylinder commands (§ 7).
- Changing the segment count **recreates** the neighboring faces: material, tag and orientation
  are kept, a texture position and attributes are lost.
- Refused (message, nothing changed): polygon, line attached in the middle of the circle, pointed
  cone, oblique cylinder, tube without a face, stacked cylinders; rounded corner with an oblique or
  cut wall, or with two different radii (resize both arcs together).
- A "broken" circle (exploded or welded edges) is ignored by the Circle tool: the cylinder commands
  rebuild it (§ 7).
- Inside a component, every copy is modified.

## 7. Resizing cylinders (Resize Cylinders…, Cylinder Resize Tool)

A **cylinder** here is a straight cylinder or truncated cone made with Push/Pull on a circle: a
smooth side wall between two coaxial circles. Holes in a block, pins on a part, dowels and
countersinks qualify. Select or click its **side wall**, not a circle.

### Resize Cylinders… (dialog)

1. Select the wall(s) of one or more cylinders (one click on the smooth side surface; Shift/Ctrl
   for more).
2. *Extensions → Circle Master → Resize Cylinders…* (or the 2nd toolbar button).
3. The window shows the number of cylinders (and cones), the size of the first one in the chosen
   **Mode** and its **Segments** count (empty, "mixed", when the selected cylinders differ).
4. Either:
   - change **Value** and/or **Segments**, then **OK** (*Enter*): only the fields you changed are
     applied; **Value** accepts everything listed under "What you can type" below;
   - or click one of the **Step** buttons, **+0.05 to +0.3** or **-0.05 to -0.3**: the step is
     added to each cylinder from its own size, with the new segment count if you changed it, and
     the window closes. Handy for the fits of 3D printed parts (clearance of a hole or a pin) or
     to correct a size.

**Mode** (**Diameter** or **Radius**, the common setting, § 9) decides what the value and the
steps apply to: in *Radius* mode, `+0.2` adds 0.2 to the radius, so 0.4 to the diameter. The
steps are in **model units**: the frame title shows them, e.g. *Step (diameter, mm)*. Changing
the mode switches the displayed value between diameter and radius. One undo step per OK or per
click; a truncated cone stays a cone with a step (no question). An error (size zero or negative,
segment count refused) is shown in red in the window, which stays open; *Cancel* or *Esc* closes
it without changing anything.

### Cylinder Resize Tool (interactive)

1. Activate the tool (3rd toolbar button).
2. Hover a cylinder (highlighted), click to pick it. **Shift/Ctrl + click** adds or removes one;
   a click outside clears the list. Cones are shown in another color, with a warning.
3. The Measurements box shows "Diameter; Segments" with the first cylinder's size and segment
   count, e.g. `50mm; 24s`. Type the new value, then *Enter*.

The tool stays active: type again to adjust, or click another cylinder. Press Space to go back to
the Select tool.

### What you can type

| Input | Effect |
|-------|--------|
| `15`, `d15` | Diameter 15 (radius if the setting is "Radius": `r` and `d` always work) |
| `r7.5` | Radius 7.5 |
| `+1`, `-0.1` | Diameter increment, for each cylinder from its own size |
| `+r0.5` | Radius increment |
| `--1` | Same as `+1` |
| `36s` | **36 segments**, same size |
| `15;36s` | Diameter 15 **and** 36 segments |
| `+0.2;48s` | Diameter + 0.2 **and** 48 segments |

- **Truncated cones**: an increment keeps the cone (same angle); an absolute value turns it into a
  cylinder, after a confirmation (*No* changes nothing); a segment count alone keeps the cone.
- **Broken circles** (plain edges, welded curves, circles cut by a solid operation, extra split
  points): the cylinder is **rebuilt with native circles** at the new size. When that is not
  possible (a line attached to a circle, stacked cylinders…), the size is still exact and the
  circles are welded into one curve (SketchUp 2020.1 and later; left as edges in SketchUp 2017).
- **Segment count**: each cylinder is rebuilt with native circles. If one of the selected
  cylinders cannot be rebuilt, **nothing is changed** and the status bar gives the reason. Typing
  the segment count it already has changes nothing.
- Holes in a block and pins on a part: the host face and its materials stay intact.
- Inside a component, open it first; its definition is edited, so all copies change.
- One undo step per input.

## 8. Which command for what?

| You want to… | Use |
|--------------|-----|
| Draw circles with an exact diameter and many segments | **Circle** |
| Change the diameter of a flat circle or arc | **Circle**, circle selected |
| Change the segment count of a cylinder, a hole or a rounded corner | **Circle** (end circle or arc selected) or the cylinder commands (wall selected) |
| Bring a whole hole or pin to an exact diameter (both ends) | **Resize Cylinders…** or **Cylinder Resize Tool** |
| Repair a hole broken by a solid operation while resizing it | the cylinder commands |

## 9. Settings

*Extensions → Circle Master → Settings…* (or the 4th toolbar button). The window can be resized;
its size and position are remembered.

| Setting | Description | Default |
|---------|-------------|---------|
| Default segment count | Used for new circles | 48 |
| Value typed without marker | **Diameter**: `50` = diameter, `25r` = radius. **Radius**: `25` = radius, `50d` = diameter. Applies to **all commands**, including the *Mode* field of *Resize Cylinders…* | Diameter |

Until a setting is changed in Circle Master, it is read from Circle Advanced (segments, input
mode, coordinate mode) or Cylinder Resize (mode); those extensions' settings are never changed.

### Advanced — Coordinate mode (inside groups)

Controls how circles drawn inside an open group or component are positioned:

- **Auto (recommended, default)**: follows what SketchUp reports for the open group.
- **World**: no conversion.
- **Local**: conversion by the transformation of the open group.

Change it **only** if circles drawn inside an open group appear at the wrong place or size. A
wrong setting misplaces every circle drawn inside groups: the warning turns red and a confirmation
is asked when saving a change.

## 10. Compatibility

- Tested on **SketchUp 2021 Pro** and **SketchUp Make 2017**, Windows (automatic test battery).
- Expected to work on SketchUp 2017 to 2027: checked against the release notes of the SketchUp
  Ruby API (Ruby 2.2 to 3.4), not tested. Before 2020.1, a circle that cannot be rebuilt as a
  native circle stays as separate edges instead of being welded.
- Does not need SketchUp Pro: no solid tool is used.
- Extension interface in English.

## 11. Known limitations

- No colored "protractor" before the first click: a small preview circle replaces it.
- Hovering an edge does not orient the circle perpendicular to it.
- The circle's first vertex may be rotated differently from the native tool.
- The toolbar buttons show as pressed only from SketchUp 2019 onwards.
- Recreated faces lose their texture position and attributes.
- An arc whose segments would be shorter than SketchUp's tolerance (0.001″ ≈ 0.025 mm) cannot be
  drawn, even by the native tools (e.g. a quarter circle of radius 0.5 mm in 48 segments).
- Circles that touch each other (tangent holes or pins): near the contact point their edges are
  only a few hundredths of a millimeter apart. When a vertex of the rebuilt circle falls closer
  than 0.001″ (≈ 0.025 mm) to the other circle, SketchUp joins them, and the change is refused
  ("… could not be rebuilt, nothing was changed"). A gap of 0.1 mm between
  them is enough.
- Thousands separators are not supported (`1,000` is read as 1 on a PC using the decimal
  point).

## 12. Troubleshooting

| Problem | Solution |
|---------|----------|
| Commands appear twice | Uninstall Circle Advanced and Cylinder Resize (§ 2) |
| Toolbar not visible | *View → Toolbars → Circle Master* |
| "Cannot modify the circle" | Draw a new circle: the previous one can no longer be modified |
| The box shows "Sides" although a circle is selected | The circle is broken or only its face is selected: click its edge, or use the cylinder commands |
| "Cylinder not supported (…)" or "Rounded corner not supported (…)" | Nothing was changed; the reason tells which condition is not met |
| "The segment count cannot be changed (…), nothing was changed" | One of the selected cylinders cannot be rebuilt (e.g. a line attached to a circle): resize it without segments, or remove the line |
| "… could not be rebuilt, nothing was changed" | The final check failed and everything was undone; please report the case with a screenshot |
| Error on load | *Window → Ruby Console*: copy the message and report it on GitHub |
