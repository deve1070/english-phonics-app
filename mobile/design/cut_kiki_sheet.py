"""Cut the sheet into five poses Flutter can serve.

Three jobs the raw sheet cannot do on its own.

BACKGROUND. The generator painted the transparency checker as real white
and grey squares. The birds are green, red, pink and black, so a
greyscale-and-bright test finds the checker -- but it also finds the eye
whites, so the mask is flood-filled inward from the border and anything
enclosed by an outline is spared. That spares the gaps between belly and
legs too, which are checker rather than bird; those come out by area,
since the largest eye white is 155px and the smallest belly gap 458.

ISOLATION. The poses are close enough on the sheet that a rectangle
around one catches a wing or a head belonging to another. So each pose is
lifted as connected shapes rather than as a box: the bird's own outline,
plus any small stray -- the motion lines beside the listening pose --
that falls entirely inside its reach. A neighbour never qualifies,
because a neighbour is not small.

ALIGNMENT. The five are drawn at slightly different sizes and sit
anywhere on the sheet. Cropping each to its own bounding box would make
the celebrating bird -- taller, because its wings are up -- shrink to fit
the same box as the others, and a mascot that changes size when its mood
changes is a different bird. So: one scale for all five, aligned on the
feet and the body's centre line. Mood changes; footing does not.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

DESIGN = Path(__file__).resolve().parent
SRC = DESIGN / "kiki_sheet_source.png"
OUT = DESIGN.parent / "assets/images/kiki"

# Measured from the labelled sheet, not guessed: (body box, mirror).
# The thinking pose is the only one drawn facing left, and a companion
# that turns round when it starts thinking reads as two birds.
POSES = [
    ("idle", (47, 91, 314, 439), False),
    ("listening", (368, 312, 674, 701), False),
    ("celebrating", (654, 78, 978, 460), False),
    ("encouraging", (70, 612, 405, 936), False),
    ("thinking", (649, 590, 953, 941), True),
]

EYE_WHITE_MAX_AREA = 300  # eyes reach 155, belly gaps start at 458
STRAY_MAX_AREA = 2000     # motion lines are ~90px; a bird is ~50000
REACH = 45                # how far a stray may sit from its bird
DENSITIES = {"": 128, "2.0x": 256, "3.0x": 384}


def components(mask: Image.Image):
    """Every connected run of set pixels, as (bbox, area, marker, image)."""
    work = mask.copy()
    wp = work.load()
    w, h = work.size
    found, marker = [], 1
    for y in range(h):
        for x in range(w):
            if wp[x, y] != 255:
                continue
            ImageDraw.floodfill(work, (x, y), marker, thresh=0)
            blob = work.point(lambda p, m=marker: 255 if p == m else 0)
            area = sum(1 for q in blob.get_flattened_data() if q)
            found.append((blob.getbbox(), area, blob))
            marker += 1
    return found


def cut_background(im: Image.Image) -> Image.Image:
    w, h = im.size
    _, sat, val = im.convert("HSV").split()
    s, v = sat.load(), val.load()

    cand = Image.new("L", (w, h), 0)
    c = cand.load()
    for y in range(h):
        for x in range(w):
            if s[x, y] < 45 and v[x, y] > 170:
                c[x, y] = 255

    ImageDraw.floodfill(cand, (0, 0), 128, thresh=0)
    bg = cand.point(lambda p: 255 if p == 128 else 0)
    # Eat one pixel inward: where checker meets the black outline the
    # blend is mid-grey, too dark to be a candidate, and survives as a
    # halo. The outlines are several pixels thick and do not miss it.
    bg = bg.filter(ImageFilter.MaxFilter(3))
    alpha = bg.point(lambda p: 0 if p else 255)

    # Enclosed checker the border fill could not reach.
    r, g, b = im.split()
    rp, gp, bp = r.load(), g.load(), b.load()
    ap = alpha.load()
    grey = Image.new("L", (w, h), 0)
    gr = grey.load()
    for y in range(h):
        for x in range(w):
            if ap[x, y] < 128:
                continue
            hi = max(rp[x, y], gp[x, y], bp[x, y])
            lo = min(rp[x, y], gp[x, y], bp[x, y])
            if hi - lo < 25 and rp[x, y] > 170:
                gr[x, y] = 255

    for box, area, blob in components(grey):
        if area < EYE_WHITE_MAX_AREA:
            continue
        bp_ = blob.load()
        for yy in range(box[1], box[3]):
            for xx in range(box[0], box[2]):
                if bp_[xx, yy]:
                    ap[xx, yy] = 0

    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out


sheet = cut_background(Image.open(SRC).convert("RGB"))
sheet.save(DESIGN / "kiki_sheet_cut.png")

shapes = components(sheet.getchannel("A").point(lambda p: 255 if p > 128 else 0))

# One canvas for all five, wide enough for the widest and tall enough for
# the tallest, with every pair of feet on a common line.
PAD = 0.07
span = max(max(b[2] - b[0], b[3] - b[1]) for _, b, _ in POSES)
side = int(span * (1 + 2 * PAD))
baseline = int(side * (1 - PAD))

for name, body, mirror in POSES:
    bl, bt, br, bb = body
    keep = Image.new("L", sheet.size, 0)
    kept = 0
    for box, area, blob in shapes:
        inside = (
            box[0] >= bl - REACH and box[1] >= bt - REACH
            and box[2] <= br + REACH and box[3] <= bb + REACH
        )
        is_body = box == body
        if is_body or (inside and area <= STRAY_MAX_AREA):
            keep.paste(255, (0, 0), blob)
            kept += 1

    piece_full = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    piece_full.paste(sheet, (0, 0), keep)
    piece_box = piece_full.getbbox()
    piece = piece_full.crop(piece_box)

    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    # Align on the bird, not on whatever travelled with it: the motion
    # lines must not drag the listening pose off its centre line.
    cx = (bl + br) / 2 - piece_box[0]
    feet = bb - piece_box[1]
    canvas.paste(piece, (int(side / 2 - cx), int(baseline - feet)), piece)
    if mirror:
        canvas = canvas.transpose(Image.FLIP_LEFT_RIGHT)

    print(f"{name:12} {kept} shape(s), crop {piece.size}")
    for folder, px in DENSITIES.items():
        target = OUT / folder if folder else OUT
        canvas.resize((px, px), Image.LANCZOS).save(target / f"kiki_{name}.png")

print(f"canvas {side}px, baseline {baseline}")
