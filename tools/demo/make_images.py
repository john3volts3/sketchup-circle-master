# Circle Master - images for the publication (development tool, not shipped
# in the .rbz).
#
# Puts together the viewport renders made by screenshots.ps1 / screenshots.rb
# (SketchUp 2021) and the real Settings window (circle_master/html/
# settings.html rendered by Chrome in headless mode, values 64 / Diameter
# filled in by a stub of the `sketchup` object), with titles and labels:
#
#   python tools/demo/make_images.py --shots <renders folder> --out <folder>
#
# Output (1380 px wide, half of it on SketchUcation: 690 px):
#   cm_segments.png  segments of circles inside a volume (before / after)
#   cm_settings.png  remembered segment count, diameter or radius
#   cm_resize.png    hole brought to an exact size
#   Circle_Master.png  54 x 54 px icon (and a x4 preview)
# Needs Pillow and Google Chrome; fonts of Windows (Segoe UI, Consolas).

import argparse
import json
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W = 1380
MARGIN = 48
BG = (255, 255, 255)
INK = (29, 33, 38)
MUTED = (88, 95, 104)
LINE = (214, 218, 224)
RED = (210, 30, 30)          # colors of the toolbar icons
BLUE = (30, 90, 200)
DARK = (40, 40, 40)
PILL_BG = (255, 255, 255)

FONTS = 'C:/Windows/Fonts'
CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe'
HERE = os.path.dirname(os.path.abspath(__file__))
SETTINGS_HTML = os.path.join(HERE, '..', '..', 'circle_master', 'html', 'settings.html')


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


F_TITLE = font('segoeuib.ttf', 46)
F_SUB = font('segoeui.ttf', 25)
F_HEAD = font('seguisb.ttf', 30)
F_TEXT = font('segoeui.ttf', 24)
F_CAPTION = font('seguisb.ttf', 26)
F_CHIP = font('seguisb.ttf', 21)
F_FOOT = font('segoeui.ttf', 21)
F_CODE = font('consolab.ttf', 28)
F_CODE_S = font('consolab.ttf', 24)


# --- Helpers ------------------------------------------------------------------

def wrap(draw, text, fnt, width):
    """Lines of +text+ fitting in +width+ pixels."""
    lines, line = [], ''
    for word in text.split(' '):
        test = (line + ' ' + word).strip()
        if draw.textlength(test, font=fnt) <= width:
            line = test
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def text_block(draw, xy, text, fnt, fill, width, spacing=1.35):
    """Draws wrapped text; returns the y below it."""
    x, y = xy
    size = fnt.size
    for line in wrap(draw, text, fnt, width):
        draw.text((x, y), line, font=fnt, fill=fill)
        y += int(size * spacing)
    return y


def header(img, title, subtitle):
    d = ImageDraw.Draw(img)
    d.text((MARGIN, 34), title, font=F_TITLE, fill=INK)
    y = text_block(d, (MARGIN, 104), subtitle, F_SUB, MUTED, W - 2 * MARGIN)
    return y + 22


def footer(img):
    d = ImageDraw.Draw(img)
    y = img.height - 46
    d.line([(MARGIN, y - 14), (W - MARGIN, y - 14)], fill=LINE, width=2)
    d.text((MARGIN, y), 'Circle Master', font=font('seguisb.ttf', 21), fill=INK)
    x = MARGIN + d.textlength('Circle Master', font=font('seguisb.ttf', 21))
    d.text((x, y), '  ·  free SketchUp extension for 3D printing', font=F_FOOT, fill=MUTED)


def background_of(im):
    return im.getpixel((2, 2))


def content_box(im, tol=10):
    """Bounding box of what differs from the background color."""
    bg = background_of(im)
    mask = Image.eval(im.convert('RGB'), lambda v: v)
    diff = Image.new('L', im.size)
    px, dpx = mask.load(), diff.load()
    w, h = im.size
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            p = px[x, y]
            if abs(p[0] - bg[0]) + abs(p[1] - bg[1]) + abs(p[2] - bg[2]) > tol:
                dpx[x, y] = 255
    return diff.getbbox()


def union(a, b):
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))


def fit_box(box, aspect, pad):
    """Box grown by +pad+ (fraction) and to the +aspect+ (w / h), centered."""
    x0, y0, x1, y1 = box
    w, h = (x1 - x0) * (1 + 2 * pad), (y1 - y0) * (1 + 2 * pad)
    if w / h < aspect:
        w = h * aspect
    else:
        h = w / aspect
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)


def crop_scaled(im, box, size):
    """Crop of +im+ (box may leave the image: background) scaled to +size+."""
    bg = background_of(im)
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    canvas = Image.new('RGB', (x1 - x0, y1 - y0), bg[:3])
    canvas.paste(im.convert('RGB'), (-x0, -y0))
    return canvas.resize(size, Image.LANCZOS)


def map_point(p, box, size, origin):
    """Point of the render to the panel placed at +origin+."""
    sx = size[0] / (box[2] - box[0])
    sy = size[1] / (box[3] - box[1])
    return (origin[0] + (p[0] - box[0]) * sx, origin[1] + (p[1] - box[1]) * sy)


def rounded_paste(img, tile, xy, radius=16):
    mask = Image.new('L', tile.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, tile.size[0] - 1, tile.size[1] - 1], radius, fill=255)
    img.paste(tile, xy, mask)
    ImageDraw.Draw(img).rounded_rectangle([xy[0], xy[1], xy[0] + tile.size[0] - 1, xy[1] + tile.size[1] - 1],
                                          radius, outline=LINE, width=2)


def chip(draw, xy, text, fill, ink=(255, 255, 255)):
    x, y = xy
    w = draw.textlength(text, font=F_CHIP)
    draw.rounded_rectangle([x, y, x + w + 28, y + 38], 19, fill=fill)
    draw.text((x + 14, y + 5), text, font=F_CHIP, fill=ink)


def pill(draw, xy, text, fnt=F_CODE, color=RED):
    """Typed input: white rounded box, colored border and monospace text.
    Returns its rectangle."""
    x, y = xy
    w = draw.textlength(text, font=fnt)
    h = fnt.size + 20
    rect = [x, y, x + w + 30, y + h]
    draw.rounded_rectangle([rect[0] + 2, rect[1] + 4, rect[2] + 2, rect[3] + 4], 10, fill=(0, 0, 0, 60))
    draw.rounded_rectangle(rect, 10, fill=PILL_BG, outline=color, width=3)
    draw.text((x + 15, y + 8), text, font=fnt, fill=color)
    return rect


def arrow(draw, start, end, color=RED, width=4, head=16):
    import math
    draw.line([start, end], fill=color, width=width)
    ang = math.atan2(end[1] - start[1], end[0] - start[0])
    left = (end[0] - head * math.cos(ang - 0.45), end[1] - head * math.sin(ang - 0.45))
    right = (end[0] - head * math.cos(ang + 0.45), end[1] - head * math.sin(ang + 0.45))
    draw.polygon([end, left, right], fill=color)


def dot(draw, p, color=RED, r=8):
    draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, 255, 255), outline=color, width=4)


def edge_point(rect, toward):
    """Point of the border of +rect+ facing +toward+ (middle of a side)."""
    x0, y0, x1, y1 = rect
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    dx, dy = toward[0] - cx, toward[1] - cy
    if abs(dx) * (y1 - y0) > abs(dy) * (x1 - x0):
        return (x1 if dx > 0 else x0, cy)
    return (cx, y1 if dy > 0 else y0)


def callout(draw, rect_xy, text, target, fnt=F_CODE):
    rect = pill(draw, rect_xy, text, fnt)
    arrow(draw, edge_point(rect, target), target)
    return rect


def dimension(draw, p1, p2, text, lift=70):
    """Diameter dimension: extension lines up from +p1+ and +p2+, a line
    with arrows between them +lift+ pixels higher, the text above it."""
    y = min(p1[1], p2[1]) - lift
    for p in (p1, p2):
        draw.line([(p[0], p[1] - 8), (p[0], y - 12)], fill=INK, width=2)
    a, b = (p1[0], y), (p2[0], y)
    mid = ((a[0] + b[0]) / 2, y)
    arrow(draw, mid, a, INK, 3, 14)
    arrow(draw, mid, b, INK, 3, 14)
    tw = draw.textlength(text, font=F_CAPTION)
    box = [mid[0] - tw / 2 - 10, y - 48, mid[0] + tw / 2 + 10, y - 10]
    draw.rounded_rectangle(box, 8, fill=(255, 255, 255, 235))
    draw.text((box[0] + 10, box[1] + 2), text, font=F_CAPTION, fill=INK)


def finish(img, bottom, path):
    """Image cut below +bottom+, footer added, saved."""
    img = img.crop((0, 0, W, bottom + 96))
    footer(img)
    img.save(path, optimize=True)


# --- Image 1: segments of circles inside a volume ---------------------------

def image_segments(shots, anchors, out):
    before = Image.open(os.path.join(shots, 'a_before.png'))
    after = Image.open(os.path.join(shots, 'a_after.png'))
    gap = 28
    pw = (W - 2 * MARGIN - gap) // 2
    ph = 480
    box = fit_box(union(content_box(before), content_box(after)), pw / ph, 0.06)

    img = Image.new('RGB', (W, 1400), BG)
    top = header(img, 'Change the segments of circles inside a volume',
                 'Pins, holes and rounded corners of a solid, after the extrusion: a few facets while '
                 'modeling, a smooth curve for the print. Entity Info cannot do it once the circle is '
                 'extruded; Circle Master can.')
    d = ImageDraw.Draw(img, 'RGBA')
    xs = [MARGIN, MARGIN + pw + gap]
    for x, im in zip(xs, [before, after]):
        rounded_paste(img, crop_scaled(im, box, (pw, ph)), (x, top))
    chip(d, (xs[0] + 16, top + ph - 54), 'BEFORE  ·  24 segments', MUTED)
    chip(d, (xs[1] + 16, top + ph - 54), 'AFTER  ·  Circle Master', RED)

    a = anchors['a_after']
    m = lambda key: map_point(a[key], box, (pw, ph), (xs[1], top))
    pin, hole, corner = m('pin'), m('hole'), m('corner')
    callout(d, (pin[0] - 230, pin[1] + 6), '64s', pin)
    callout(d, (hole[0] + 80, hole[1] - 150), '64s', hole)
    callout(d, (corner[0] + 70, corner[1] - 14), '16s', corner)
    for p in (pin, hole, corner):
        dot(d, p)

    y = top + ph + 18
    text_block(d, (xs[0] + 4, y), '24 segments: facets you see and feel on the print.', F_TEXT, MUTED, pw - 8)
    y = text_block(d, (xs[1] + 4, y), 'Select a circle of the pin or the hole, type 64s; 16s on a '
                   'rounded corner. The whole volume follows, the faces stay tangent.', F_TEXT, MUTED, pw - 8)
    finish(img, y, os.path.join(out, 'cm_segments.png'))


# --- Image 2: settings kept from one session to the next --------------------

def settings_window(work):
    """The Settings window: settings.html rendered by Chrome (2x), values
    filled in by a stub of the `sketchup` object, with a title bar."""
    with open(SETTINGS_HTML, encoding='utf-8') as f:
        html = f.read()
    stub = ("<script>window.sketchup = { ready: function () { setValues({segments: 64, "
            "mode: 'diameter', coord: 'auto', min: 3, max: 999}); }, save: function () {}, "
            "cancel: function () {} };</script>\n</head>")
    page = os.path.join(work, 'settings_stub.html')
    with open(page, 'w', encoding='utf-8') as f:
        f.write(html.replace('</head>', stub, 1))
    shot = os.path.join(work, 'settings_content.png')
    # 500 px: the smallest width of a Chrome window in headless mode (the
    # Settings window can be resized).
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
                    '--user-data-dir=' + os.path.join(work, 'profile'), '--force-device-scale-factor=2',
                    '--window-size=500,470', '--screenshot=' + shot, 'file:///' + page.replace('\\', '/')],
                   check=True, capture_output=True)
    content = Image.open(shot).convert('RGB')
    bar = 64
    win = Image.new('RGB', (content.width, content.height + bar), (255, 255, 255))
    win.paste(content, (0, bar))
    d = ImageDraw.Draw(win)
    d.text((28, 14), 'Circle Master — Settings', font=font('segoeui.ttf', 26), fill=INK)
    cx, cy = content.width - 46, bar // 2
    d.line([(cx - 11, cy - 11), (cx + 11, cy + 11)], fill=INK, width=3)
    d.line([(cx - 11, cy + 11), (cx + 11, cy - 11)], fill=INK, width=3)
    d.rectangle([0, 0, win.width - 1, win.height - 1], outline=(150, 150, 150), width=2)
    return win, bar


def note(draw, start, text, color):
    """Short arrow pointing left to +start+, then the text."""
    x, y = start
    arrow(draw, (x + 46, y), (x, y), color, 4, 14)
    draw.text((x + 56, y - 15), text, font=font('seguisb.ttf', 23), fill=color)


def image_settings(shots, anchors, out, work):
    win, bar = settings_window(work)
    ww = 620
    scale = ww / win.width
    win_s = win.resize((ww, int(win.height * scale)), Image.LANCZOS)

    img = Image.new('RGB', (W, 1400), BG)
    top = header(img, 'Your settings, from one session to the next',
                 'Choose your segment count and how a typed value is read, once: every Circle '
                 'Master command uses them, today and after SketchUp restarts.')
    # Window with a soft shadow.
    wx, wy = MARGIN, top + 4
    shadow = Image.new('RGBA', (win_s.width + 60, win_s.height + 60), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rectangle([30, 34, 30 + win_s.width, 34 + win_s.height], fill=(0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    img.paste(shadow, (wx - 30, wy - 30), shadow)
    img.paste(win_s, (wx, wy))
    d = ImageDraw.Draw(img, 'RGBA')

    # Notes in the empty part of the window (content pixels at 2x: segment
    # field ends at x 215, y 160; "Diameter" label ends at x 210, y 287).
    def win_point(x, y2):
        return (wx + x * scale, wy + (y2 + bar) * scale)
    note(d, win_point(232, 160), 'kept between sessions', RED)
    note(d, win_point(225, 287), 'or Radius: your choice', BLUE)
    win_bottom = wy + win_s.height

    # Right column.
    rx = wx + ww + 64
    rw = W - MARGIN - rx
    y = top + 4
    d.text((rx, y), 'Your segment count, every session', font=F_HEAD, fill=INK)
    y = text_block(d, (rx, y + 48), "SketchUp's own Circle tool goes back to 24 segments after "
                   'each restart. Circle Master keeps yours: 48 by default, any count from 3 to 999.',
                   F_TEXT, MUTED, rw)
    discs = Image.open(os.path.join(shots, 'b.png'))
    dh = 230
    box = fit_box(content_box(discs), rw / dh, 0.14)
    rounded_paste(img, crop_scaled(discs, box, (rw, dh)), (rx, y + 10))
    y += 10 + dh + 10
    half = rw // 2
    for i, (label, color) in enumerate([('Native tool after a restart: 24', MUTED),
                                        ('Circle Master: your 64', RED)]):
        tw = d.textlength(label, font=F_CHIP)
        d.text((rx + i * half + (half - tw) / 2, y), label, font=F_CHIP, fill=color)
    y += 64

    d.text((rx, y), 'A diameter or a radius', font=F_HEAD, fill=INK)
    y += 54
    rows = [('25', 'diameter 25'), ('12.5r', 'radius 12.5'), ('25;64s', 'diameter 25 and 64 segments'),
            ('+0.2', '0.2 larger, from its own size')]
    for code, meaning in rows:
        pill(d, (rx, y), code, F_CODE_S, BLUE)
        d.text((rx + 150, y + 7), meaning, font=F_TEXT, fill=INK)
        y += 56
    y = text_block(d, (rx, y + 4), 'Radius by default? One click in Settings.', F_TEXT, MUTED, rw)
    finish(img, max(y, win_bottom + 10), os.path.join(out, 'cm_settings.png'))


# --- Image 3: exact hole size ------------------------------------------------

def image_resize(shots, anchors, out):
    before = Image.open(os.path.join(shots, 'c_before.png'))
    after = Image.open(os.path.join(shots, 'c_after.png'))
    mid = 190
    pw = (W - 2 * MARGIN - mid) // 2
    ph = 430
    box = fit_box(union(content_box(before), content_box(after)), pw / ph, 0.06)

    img = Image.new('RGB', (W, 1400), BG)
    top = header(img, 'Exact hole and pin sizes for 3D printing',
                 'Cylinder Resize Tool: click the wall of a hole or a pin and type the size. Both '
                 'ends change, the face around keeps its edges and materials. Holes cut by solid '
                 'tools are rebuilt as native circles.')
    xs = [MARGIN, W - MARGIN - pw]
    for x, im in zip(xs, [before, after]):
        rounded_paste(img, crop_scaled(im, box, (pw, ph)), (x, top))
    d = ImageDraw.Draw(img, 'RGBA')
    chip(d, (xs[0] + 16, top + 16), 'BEFORE', MUTED)
    chip(d, (xs[1] + 16, top + 16), 'AFTER', RED)
    for x, key, text in [(xs[0], 'c_before', 'Ø 5.0'), (xs[1], 'c_after', 'Ø 5.2')]:
        a = anchors[key]
        m = lambda k: map_point(a[k], box, (pw, ph), (x, top))
        dimension(d, m('left'), m('right'), text)

    # Typed input between the panels.
    cy = top + ph // 2
    code = '5.2;48s'
    tw = d.textlength(code, font=F_CODE)
    rect = pill(d, (W // 2 - (tw + 30) / 2, cy - 70), code)
    arrow(d, (xs[0] + pw + 22, cy + 10), (xs[1] - 22, cy + 10), RED, 6, 22)
    d.text((W // 2 - d.textlength('Enter', font=F_TEXT) / 2, rect[3] + 52), 'Enter', font=F_TEXT, fill=MUTED)

    y = top + ph + 20
    for x, big, small in [(xs[0], 'Ø 5.0  ·  24 segments', 'Hole drawn at the nominal size.'),
                          (xs[1], 'Ø 5.2  ·  48 segments', 'Printing clearance in one input; +0.2 works too.')]:
        d.text((x + 4, y), big, font=F_CAPTION, fill=INK)
        d.text((x + 4, y + 40), small, font=F_TEXT, fill=MUTED)
    finish(img, y + 72, os.path.join(out, 'cm_resize.png'))


# --- Icon ---------------------------------------------------------------------

def icon(out, name='Circle_Master'):
    """54 x 54 px: the circle of the toolbar icon, half of it in visible
    facets (4 segments), half smooth, and the red diameter."""
    import math
    s = 4 * 54
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c, r, w = s / 2, s * 0.40, 15
    # Left half: 4 segments on a half turn (octagon); right half: smooth.
    pts = [(c + r * math.cos(math.pi / 2 + i * math.pi / 4), c - r * math.sin(math.pi / 2 + i * math.pi / 4))
           for i in range(5)]
    d.line(pts, fill=DARK + (255,), width=w, joint='curve')
    for p in pts:
        d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=DARK + (255,))
    d.arc([c - r - w / 2, c - r - w / 2, c + r + w / 2, c + r + w / 2], -90, 90, fill=DARK + (255,), width=w)
    d.line([(c - r - w / 2 - 6, c), (c + r + w / 2 + 6, c)], fill=RED + (255,), width=15)
    small = im.resize((54, 54), Image.LANCZOS)
    small.save(os.path.join(out, name + '.png'))
    small.resize((216, 216), Image.NEAREST).save(os.path.join(out, name + '-preview-x4.png'))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--shots', required=True, help='folder of the renders (screenshots.ps1 -OutDir)')
    ap.add_argument('--out', required=True)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.shots, 'anchors.json'), encoding='utf-8') as f:
        anchors = json.load(f)
    work = tempfile.mkdtemp(prefix='cm_images_')
    image_segments(args.shots, anchors, args.out)
    image_settings(args.shots, anchors, args.out, work)
    image_resize(args.shots, anchors, args.out)
    icon(args.out)
    print('Images written in', args.out)


if __name__ == '__main__':
    main()
