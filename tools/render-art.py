#!/usr/bin/env python3
"""render-art.py — draws the BRAINROT TYCOON screenshots and game icon.

No Roblox Studio exists on this machine, so the screenshots are honest
isometric renders of the actual game world: every part is read from
default.project.json (positions, sizes, colours the world generator
emitted) and projected isometrically, and the brainrots standing in the
scenes are drawn the way BrainrotFactory builds them (body, head, eyes,
rarity gem, plus the Look accessories). The icon is a 2D cover piece:
the blocky Roblox avatar next to the Dewa Langit mascot, with the
BRAINROT TYCOON wordmark.

Usage: python3 tools/render-art.py
Writes screenshots/1..4 and ../brainrot-icon.png (repo-external).
"""
import json
import math
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

W, H = 1280, 720

RARITY = {
    "Common": (178, 190, 181),
    "Rare": (84, 150, 255),
    "Epic": (178, 102, 255),
    "Legendary": (255, 196, 46),
    "Mythic": (255, 84, 150),
    "Dewa Langit": (255, 242, 194),
}

# Mirror of BrainrotDefs (name -> look data) for the creatures we stage.
CREATURES = {
    "Noobini": dict(rarity="Common", scale=0.9, color=(245, 205, 48), look={}),
    "DJ Bananini": dict(rarity="Rare", scale=1.1, color=(255, 225, 90), look={}),
    "Glorbo Melonini": dict(rarity="Epic", scale=1.2, color=(90, 190, 110), look={}),
    "Robo Rizzini": dict(rarity="Epic", scale=1.3, color=(150, 170, 190), look={"antenna": True}),
    "King Kokonut": dict(rarity="Legendary", scale=1.4, color=(140, 95, 55), look={"crown": True}),
    "Pavone Reale": dict(rarity="Legendary", scale=1.5, color=(60, 200, 170), look={"crown": True, "tail": "Fan", "wings": "Small"}),
    "Gatto Galattico": dict(rarity="Mythic", scale=1.65, color=(90, 60, 160), look={"ears": "Point", "halo": True}),
    "Drago Vulcano": dict(rarity="Mythic", scale=1.75, color=(200, 70, 40), look={"horns": True, "wings": "Big"}),
    "Godini Brainrotti": dict(rarity="Mythic", scale=1.8, color=(255, 215, 90), look={"crown": True, "halo": True}),
    "Naga Langit Suci": dict(rarity="Dewa Langit", scale=3.0, color=(250, 244, 220), look={"horns": True, "wings": "Huge", "crown": True, "halo": True}),
    "Paus Bulan": dict(rarity="Dewa Langit", scale=3.6, color=(200, 215, 255), look={"fin": True, "halo": True}),
}


def shade(color, f):
    return tuple(max(0, min(255, int(c * f))) for c in color)


def lerp_color(color, target, f):
    return tuple(int(c + (t - c) * f) for c, t in zip(color, target))


def font(size, bold=True):
    return ImageFont.truetype(FONT_BOLD if bold else FONT, size)


# ---------------------------------------------------------------- parts
def load_parts():
    with open(os.path.join(ROOT, "default.project.json")) as fh:
        project = json.load(fh)
    workspace = project["tree"]["Workspace"]
    parts = []
    flat_names = {"Ground", "ApronN", "ApronS", "ShopSand", "DirtPath"}

    def walk(node, name=""):
        if not isinstance(node, dict):
            return
        if node.get("$className") == "Part":
            props = node.get("$properties", {})
            if "Position" in props and "Size" in props:
                parts.append({
                    "size": props["Size"],
                    "pos": props["Position"],
                    "color": tuple(int(round(c * 255)) for c in props.get("Color", [1, 1, 1])),
                    "shape": props.get("Shape"),
                    "material": props.get("Material"),
                    "transparency": props.get("Transparency", 0),
                    # Flat ground coverings paint first: the 460-wide ground
                    # slab's centre depth would otherwise swallow the bases.
                    "layer": 0 if (name in flat_names or name.startswith("Tile")) else 1,
                })
        for key, value in node.items():
            walk(value, key)

    walk(workspace)
    return parts


PARTS = load_parts()


# ------------------------------------------------------------ isometric
class Iso:
    """Isometric projector: world (x, y, z) -> screen pixels."""

    def __init__(self, cx, cy, cz, scale, ox, oy):
        self.c = (cx, cy, cz)
        self.s = scale
        self.o = (ox, oy)

    def p(self, x, y, z):
        dx, dy, dz = x - self.c[0], y - self.c[1], z - self.c[2]
        sx = (dx - dz) * 0.8660254
        sy = (dx + dz) * 0.5 - dy
        return (self.o[0] + sx * self.s, self.o[1] + sy * self.s)


def draw_box(draw, iso, pos, size, color, alpha=255):
    x, y, z = pos
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    top = [iso.p(x - hx, y + hy, z - hz), iso.p(x + hx, y + hy, z - hz),
           iso.p(x + hx, y + hy, z + hz), iso.p(x - hx, y + hy, z + hz)]
    east = [iso.p(x + hx, y + hy, z - hz), iso.p(x + hx, y - hy, z - hz),
            iso.p(x + hx, y - hy, z + hz), iso.p(x + hx, y + hy, z + hz)]
    south = [iso.p(x - hx, y + hy, z + hz), iso.p(x + hx, y + hy, z + hz),
             iso.p(x + hx, y - hy, z + hz), iso.p(x - hx, y - hy, z + hz)]
    if alpha < 255:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.polygon(south, fill=shade(color, 0.62) + (alpha,))
        ld.polygon(east, fill=shade(color, 0.82) + (alpha,))
        ld.polygon(top, fill=shade(color, 1.22) + (alpha,))
        return layer
    draw.polygon(south, fill=shade(color, 0.62))
    draw.polygon(east, fill=shade(color, 0.82))
    draw.polygon(top, fill=shade(color, 1.22))
    return None


def draw_ball(draw, iso, pos, size, color):
    cx, cy = iso.p(*pos)
    rx = (size[0] + size[2]) * 0.433 * iso.s
    ry = size[1] * 0.62 * iso.s
    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=shade(color, 1.05),
                 outline=shade(color, 0.7), width=max(1, int(iso.s * 0.12)))


def render_world(iso, extra_parts=()):
    """Draws every world part back-to-front, plus any staged extra parts
    (dicts like the loaded ones, drawn in the same depth pass)."""
    img = Image.new("RGB", (W, H), (118, 202, 248))
    draw = ImageDraw.Draw(img, "RGBA")
    all_parts = list(PARTS) + list(extra_parts)
    all_parts.sort(key=lambda pt: (pt.get("layer", 1), pt["pos"][0] + pt["pos"][2], pt["pos"][1]))
    layers = []
    for pt in all_parts:
        if pt["transparency"] and pt["transparency"] > 0.6:
            continue
        if pt["shape"] == "Ball":
            if pt.get("transparency", 0) > 0:
                layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                ld = ImageDraw.Draw(layer)
                cx, cy = iso.p(*pt["pos"])
                rx = (pt["size"][0] + pt["size"][2]) * 0.433 * iso.s
                ry = pt["size"][1] * 0.62 * iso.s
                a = int(255 * (1 - pt["transparency"]))
                ld.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=shade(pt["color"], 1.05) + (a,))
                layers.append(layer)
            else:
                draw_ball(draw, iso, pt["pos"], pt["size"], pt["color"])
        else:
            alpha = int(255 * (1 - pt.get("transparency", 0)))
            layer = draw_box(draw, iso, pt["pos"], pt["size"], pt["color"], alpha)
            if layer is not None:
                layers.append(layer)
    for layer in layers:
        img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    return img


# ------------------------------------------------- staged world actors
def creature_part(x, y, z, name):
    """A staged creature is returned as draw instructions, not a part:
    the factory model is several boxes, drawn by draw_creature_iso."""
    return ("creature", x, y, z, name)


def draw_creature_iso(draw, iso, x, y, z, name, tag=True):
    """Draws one brainrot the way BrainrotFactory builds it: body box,
    lighter head, eyes on the south face, rarity gem, Look accessories.
    Feet at (x, y, z); faces the lane (+Z south face is the face)."""
    spec = CREATURES[name]
    s = spec["scale"]
    color = spec["color"]
    look = spec["look"]
    body_h = 3.2 * s
    head_s = 2.1 * s
    # rarity ring on the ground
    if tag:
        cx, cy = iso.p(x, y + 0.15, z)
        rr = RARITY[spec["rarity"]]
        rx = 2.1 * s * iso.s * 0.9
        ry = rx * 0.45
        draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=rr, width=max(2, int(iso.s * 0.35)))
    # tail fan behind (drawn first, it is at the back)
    if look.get("tail") == "Fan":
        bx, by = iso.p(x, y + body_h * 0.62, z - 1.4 * s)
        for i in range(-2, 3):
            dx = i * 0.62 * s * iso.s * 0.8
            draw.polygon([(bx + dx, by), (bx + dx - 6 * s * iso.s * 0.2, by - 2.4 * s * iso.s),
                          (bx + dx + 6 * s * iso.s * 0.2, by - 2.4 * s * iso.s)],
                         fill=shade(color, 0.78))
    # wings behind the body
    if look.get("wings"):
        wmul = {"Small": 0.95, "Big": 1.35, "Huge": 1.9}[look["wings"]]
        wy = y + body_h * 0.8
        for sgn in (-1, 1):
            tip = iso.p(x + sgn * (1.6 + 2.4 * wmul) * s, wy + 1.2 * s, z - 0.6 * s)
            base1 = iso.p(x + sgn * 1.2 * s, wy, z - 0.9 * s)
            base2 = iso.p(x + sgn * 1.2 * s, wy - 1.4 * s, z - 0.9 * s)
            draw.polygon([base1, tip, base2], fill=shade(lerp_color(color, (255, 255, 255), 0.3), 0.95))
    draw_box(draw, iso, (x, y + body_h / 2, z), (3 * s, body_h, 2.2 * s), color)
    head_y = y + body_h + head_s / 2
    draw_box(draw, iso, (x, head_y, z), (head_s, head_s, head_s), lerp_color(color, (255, 255, 255), 0.18))
    # eyes on the south face of the head
    fx, fy = iso.p(x, head_y + head_s * 0.08, z + head_s / 2 + 0.05)
    ex = head_s * 0.24 * iso.s * 0.87
    er = max(1.5, 0.16 * s * iso.s)
    for sgn in (-1, 1):
        draw.ellipse([fx + sgn * ex - er, fy - er * 1.4, fx + sgn * ex + er, fy + er * 1.4], fill=(20, 20, 25))
    # gem on the chest (south face of the body)
    gx, gy = iso.p(x, y + body_h * 0.55, z + 1.1 * s + 0.05)
    gr = 0.45 * s * iso.s
    draw.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=RARITY[spec["rarity"]])
    # crown
    if look.get("crown"):
        cx2, cy2 = iso.p(x, head_y + head_s / 2, z)
        cw = head_s * 0.92 * iso.s * 0.8
        ch = 0.5 * s * iso.s
        draw.rectangle([cx2 - cw / 2, cy2 - ch, cx2 + cw / 2, cy2], fill=(255, 205, 55))
        for i in range(4):
            sx = cx2 - cw / 2 + i * (cw / 3)
            draw.polygon([(sx - 3, cy2 - ch), (sx + 3, cy2 - ch), (sx, cy2 - ch - ch * 0.9)], fill=(255, 205, 55))
    # halo above everything
    if look.get("halo"):
        hx, hy = iso.p(x, head_y + head_s / 2 + 1.15 * s, z)
        hrx = 1.15 * s * iso.s * 0.87
        hry = hrx * 0.32
        draw.ellipse([hx - hrx, hy - hry, hx + hrx, hy + hry], outline=(255, 240, 170), width=max(2, int(iso.s * 0.4)))
    # name tag
    if tag:
        tx, ty = iso.p(x, head_y + head_s / 2 + (1.7 * s if look.get("halo") else 1.1), z)
        f1 = font(max(11, int(iso.s * 2.6)))
        draw.text((tx, ty), name, font=f1, fill=RARITY[spec["rarity"]], anchor="mb",
                  stroke_width=2, stroke_fill=(30, 30, 40))


def draw_avatar_iso(draw, iso, x, y, z):
    """The blocky Roblox avatar: yellow head with a smile, bright blue
    torso, green legs — classic proportions, drawn from boxes."""
    draw_box(draw, iso, (x - 0.55, y + 0.75, z), (0.9, 1.5, 1.0), (120, 200, 80))   # leg L
    draw_box(draw, iso, (x + 0.55, y + 0.75, z), (0.9, 1.5, 1.0), (120, 200, 80))   # leg R
    draw_box(draw, iso, (x, y + 2.4, z), (2.1, 1.9, 1.1), (30, 110, 220))           # torso
    draw_box(draw, iso, (x - 1.45, y + 2.4, z), (0.7, 1.9, 1.0), (245, 205, 48))    # arm L
    draw_box(draw, iso, (x + 1.45, y + 2.4, z), (0.7, 1.9, 1.0), (245, 205, 48))    # arm R
    draw_box(draw, iso, (x, y + 4.05, z), (1.5, 1.5, 1.5), (245, 205, 48))          # head
    fx, fy = iso.p(x, y + 4.15, z + 0.78)
    er = max(1.5, iso.s * 0.28)
    for sgn in (-1, 1):
        ex = sgn * 0.32 * iso.s
        draw.ellipse([fx + ex - er * 0.6, fy - er, fx + ex + er * 0.6, fy + er], fill=(20, 20, 25))
    draw.arc([fx - 0.42 * iso.s, fy + 0.05 * iso.s, fx + 0.42 * iso.s, fy + 0.62 * iso.s],
             start=15, end=165, fill=(20, 20, 25), width=max(2, int(iso.s * 0.3)))


def draw_wave(draw, iso, x):
    """The tsunami wall: a translucent blue box with a foam lip."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    drawn = draw_box(ld, iso, (x, 13, 0), (24, 26, 52), (60, 150, 235), alpha=110)
    if drawn is not None:
        layer = Image.alpha_composite(layer, drawn)
    ld = ImageDraw.Draw(layer)
    foam = [iso.p(x - 12, 26.4, -26), iso.p(x + 12, 26.4, -26), iso.p(x + 12, 26.4, 26), iso.p(x - 12, 26.4, 26)]
    ld.polygon(foam, fill=(240, 250, 255, 190))
    return layer


# ------------------------------------------------------------ HUD bits
def rounded(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_hud(draw, coin="12,350", income="+1,240/s", speed="29", rebirths="2", clock="Day 2", night=False):
    rounded(draw, [320, 12, 960, 62], 14, (24, 24, 32, 215))
    draw.text((338, 24), "Coin: " + coin, font=font(25), fill=(140, 255, 150))
    draw.text((565, 27), income, font=font(20), fill=(255, 226, 130))
    draw.text((730, 27), "Speed " + speed, font=font(20), fill=(150, 220, 255))
    draw.text((852, 27), "Rebirths " + rebirths, font=font(20), fill=(210, 190, 255))
    rounded(draw, [545, 72, 735, 112], 10, (24, 24, 32, 200))
    # a little sun (or moon) dot beside the phase text
    dot_color = (150, 170, 255) if night else (255, 205, 80)
    draw.ellipse([560, 82, 576, 98], fill=dot_color)
    draw.text((646, 80), clock, font=font(19), fill=(255, 255, 255), anchor="ma")
    rounded(draw, [556, 100, 724, 107], 3, (255, 205, 80))


def draw_toast(draw, text, y=596):
    f = font(23)
    tw = draw.textlength(text, font=f)
    rounded(draw, [640 - tw / 2 - 18, y - 8, 640 + tw / 2 + 18, y + 38], 10, (24, 24, 32, 190))
    draw.text((640, y), text, font=f, fill=(255, 255, 255), anchor="ma")


def save(img, path):
    img.save(path)
    if os.path.getsize(path) > 262144:
        img.convert("P", palette=Image.ADAPTIVE, colors=256).save(path)
    print(path, os.path.getsize(path), "bytes")


# ------------------------------------------------------- 2D cover art
def draw_avatar_2d(draw, cx, ground, h):
    """Front-view blocky Roblox avatar: yellow head and arms, bright
    blue torso, green legs, big smile. (cx, ground) = feet centre."""
    u = h / 5.0  # five classic blocks tall
    w_leg, w_torso = 0.42 * u, 1.5 * u
    # legs
    draw.rectangle([cx - w_torso / 2, ground - u, cx - 0.04 * u, ground], fill=(120, 200, 80), outline=(70, 130, 45), width=3)
    draw.rectangle([cx + 0.04 * u, ground - u, cx + w_torso / 2, ground], fill=(120, 200, 80), outline=(70, 130, 45), width=3)
    # arms (left arm raised in a wave)
    draw.rectangle([cx - w_torso / 2 - 0.34 * u, ground - 2.9 * u, cx - w_torso / 2, ground - 1.05 * u], fill=(245, 205, 48), outline=(190, 155, 30), width=3)
    draw.rectangle([cx + w_torso / 2, ground - 3.6 * u, cx + w_torso / 2 + 0.34 * u, ground - 1.75 * u], fill=(245, 205, 48), outline=(190, 155, 30), width=3)
    # torso
    draw.rectangle([cx - w_torso / 2, ground - 2.95 * u, cx + w_torso / 2, ground - u], fill=(30, 110, 220), outline=(18, 70, 150), width=3)
    # head
    hs = 1.15 * u
    draw.rectangle([cx - hs / 2, ground - 2.95 * u - hs, cx + hs / 2, ground - 2.95 * u], fill=(245, 205, 48), outline=(190, 155, 30), width=3)
    cy = ground - 2.95 * u - hs * 0.45
    for sgn in (-1, 1):
        ex = cx + sgn * hs * 0.22
        draw.ellipse([ex - hs * 0.07, cy - hs * 0.16, ex + hs * 0.07, cy + hs * 0.02], fill=(20, 20, 25))
    draw.arc([cx - hs * 0.26, cy - hs * 0.02, cx + hs * 0.26, cy + hs * 0.34], start=15, end=165, fill=(20, 20, 25), width=max(3, int(u * 0.07)))


def draw_mascot_2d(draw, cx, ground, h):
    """Naga Langit Suci, the Dewa Langit mascot: a colossal white-gold
    sky dragon — huge wings, gold horns and crown, a glowing halo."""
    body_w = h * 0.52
    body_h = h * 0.52
    body_top = ground - body_h
    # wings behind the body
    for sgn in (-1, 1):
        tip_x = cx + sgn * h * 0.46
        draw.polygon([(cx + sgn * body_w * 0.3, body_top + body_h * 0.25),
                      (tip_x, body_top - h * 0.30),
                      (cx + sgn * body_w * 0.42, body_top + body_h * 0.62)],
                     fill=(238, 228, 200), outline=(196, 178, 132))
    # tail fan
    for i in range(-2, 3):
        x0 = cx + i * body_w * 0.16
        draw.polygon([(x0, ground - body_h * 0.35), (x0 - body_w * 0.07, ground - body_h * 0.02),
                      (x0 + body_w * 0.07, ground - body_h * 0.02)], fill=(226, 214, 178))
    # body
    draw.rounded_rectangle([cx - body_w / 2, body_top, cx + body_w / 2, ground], radius=h * 0.05,
                           fill=(250, 244, 220), outline=(206, 188, 142), width=4)
    # head
    hs = h * 0.34
    head_top = body_top - hs * 0.92
    draw.rounded_rectangle([cx - hs / 2, head_top, cx + hs / 2, head_top + hs], radius=h * 0.04,
                           fill=(252, 248, 232), outline=(206, 188, 142), width=4)
    # horns
    for sgn in (-1, 1):
        hx = cx + sgn * hs * 0.30
        draw.polygon([(hx - hs * 0.09, head_top + hs * 0.08), (hx + hs * 0.09, head_top + hs * 0.08),
                      (hx + sgn * hs * 0.16, head_top - hs * 0.30)], fill=(255, 205, 55), outline=(196, 150, 30))
    # crown
    cw = hs * 0.8
    cy0 = head_top - hs * 0.02
    draw.rectangle([cx - cw / 2, cy0 - hs * 0.16, cx + cw / 2, cy0 + hs * 0.05], fill=(255, 205, 55), outline=(196, 150, 30), width=2)
    for i in range(4):
        sx = cx - cw / 2 + i * (cw / 3)
        draw.polygon([(sx - hs * 0.05, cy0 - hs * 0.16), (sx + hs * 0.05, cy0 - hs * 0.16), (sx, cy0 - hs * 0.34)], fill=(255, 205, 55))
    # halo
    hrx, hry = hs * 0.62, hs * 0.16
    hy = head_top - hs * 0.52
    draw.ellipse([cx - hrx, hy - hry, cx + hrx, hy + hry], outline=(255, 240, 170), width=max(4, int(h * 0.02)))
    # face
    fy = head_top + hs * 0.52
    for sgn in (-1, 1):
        ex = cx + sgn * hs * 0.21
        draw.ellipse([ex - hs * 0.06, fy - hs * 0.13, ex + hs * 0.06, fy + hs * 0.03], fill=(30, 28, 40))
    draw.arc([cx - hs * 0.2, fy + hs * 0.02, cx + hs * 0.2, fy + hs * 0.3], start=15, end=165, fill=(30, 28, 40), width=max(3, int(h * 0.012)))
    # rarity gem on the chest
    gx, gy = cx, body_top + body_h * 0.45
    gr = h * 0.055
    draw.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=(255, 242, 194), outline=(255, 205, 55), width=3)


# ------------------------------------------------------------- shots
def shot_thumbnail():
    """Full-bleed cover, composed like the genre's reference thumbnails:
    a bright world scene edge to edge, a giant income figure lettered
    across the top in our currency, the Dewa Langit mascot large on
    the right, our blocky avatar on the left, and the title bold along
    the bottom. No frame — the art runs to every edge."""
    iso = Iso(-6, 4, 0, 3.0, 640, 330)
    img = render_world(iso)
    draw = ImageDraw.Draw(img, "RGBA")
    actors = [
        ("creature", 34, 1.1, 0, "Paus Bulan"),
        ("creature", -34, 1.1, 0, "Drago Vulcano"),
        ("creature", -58, 1.1, 0, "DJ Bananini"),
        ("creature", 3, 1.25, -63, "King Kokonut"),
        ("creature", -81, 1.25, -45, "Gatto Galattico"),
        ("avatar", -84, 1.15, 27, None),
    ]
    for kind, x, y, z, name in sorted(actors, key=lambda a: a[1] + a[3]):
        if kind == "creature":
            draw_creature_iso(draw, iso, x, y, z, name)
        else:
            draw_avatar_iso(draw, iso, x, y, z)
    # The giant income figure across the top — Paus Bulan's 600,000
    # Coin/s, the biggest income in the game, in chunky stroked gold.
    f_income = font(104)
    draw.text((W / 2, 16), "600,000 Coin/s", font=f_income, anchor="ma",
              fill=(255, 214, 64), stroke_width=14, stroke_fill=(32, 28, 64))
    # Title along the bottom on a soft dark band so it reads over the
    # world; the foreground pair stands in front of the band's ends.
    draw.rectangle([0, 580, W, H], fill=(18, 20, 38, 168))
    draw.text((W / 2, 592), "BRAINROT TYCOON", font=font(68), anchor="ma",
              fill=(255, 246, 205), stroke_width=8, stroke_fill=(30, 26, 60))
    # foreground cover pair: avatar left, Dewa Langit mascot right
    draw.ellipse([60, 630, 320, 670], fill=(0, 0, 0, 60))
    draw.ellipse([884, 624, 1232, 672], fill=(0, 0, 0, 60))
    draw_avatar_2d(draw, 190, 646, 240)
    draw_mascot_2d(draw, 1058, 646, 305)
    save(img, os.path.join(ROOT, "screenshots", "1-thumbnail.png"))


def shot_conveyor():
    iso = Iso(-50, 3, 12, 6.0, 620, 150)
    img = render_world(iso)
    draw = ImageDraw.Draw(img, "RGBA")
    draw_creature_iso(draw, iso, -26, 1.1, 0, "Drago Vulcano")
    draw_creature_iso(draw, iso, -44, 1.1, 0, "Noobini")
    draw_creature_iso(draw, iso, -6, 1.1, 0, "Glorbo Melonini")
    draw_avatar_iso(draw, iso, -64, 1.15, 30)  # running on the treadmill
    draw_hud(draw)
    # treadmill meter
    rounded(draw, [470, 618, 810, 664], 10, (24, 24, 32, 210))
    draw.text((640, 624), "TREADMILL — keep running!", font=font(16), fill=(255, 255, 255), anchor="ma")
    rounded(draw, [486, 646, 794, 656], 4, (10, 10, 16))
    rounded(draw, [486, 646, 486 + 308 * 0.68, 656], 4, (120, 255, 160))
    draw_toast(draw, "A Mythic on the belt — and the treadmill pays out!", y=540)
    save(img, os.path.join(ROOT, "screenshots", "2-conveyor.png"))


def shot_base():
    iso = Iso(0, 2, -56, 9.5, 640, 330)
    img = render_world(iso)
    draw = ImageDraw.Draw(img, "RGBA")
    draw_creature_iso(draw, iso, -9, 1.25, -63, "King Kokonut")
    draw_creature_iso(draw, iso, 3, 1.25, -54, "Gatto Galattico")
    draw_creature_iso(draw, iso, 12, 1.25, -63, "Robo Rizzini")
    draw_creature_iso(draw, iso, -15, 1.25, -45, "Pavone Reale")
    # the incubating egg in the nest (Base2 nest at (-13, -38.2))
    ex, ey = iso.p(-13, 2.4, -38.2)
    draw.ellipse([ex - 15, ey - 20, ex + 15, ey + 20], fill=(255, 84, 150), outline=(255, 205, 55), width=3)
    draw_hud(draw, coin="248,900", income="+9,860/s", speed="35", rebirths="3", clock="Day 4")
    draw_toast(draw, "Pen Lv.12 — 17 pads unlocked · Telur Mythic hatching…")
    save(img, os.path.join(ROOT, "screenshots", "3-base.png"))


def shot_tsunami():
    iso = Iso(26, 2, 0, 5.6, 640, 300)
    img = render_world(iso)
    wave = draw_wave(ImageDraw.Draw(img), iso, 14)
    img = Image.alpha_composite(img.convert("RGBA"), wave).convert("RGB")
    draw = ImageDraw.Draw(img, "RGBA")
    draw_creature_iso(draw, iso, 56, 1.1, 0, "DJ Bananini")
    draw_avatar_iso(draw, iso, -14, 0.15, 17)
    draw_hud(draw, clock="Night 4", night=True)
    rounded(draw, [330, 128, 950, 186], 12, (180, 40, 40, 225))
    draw.text((640, 141), "TSUNAMI IN 5s — GET TO A BASE!", font=font(27), fill=(255, 255, 255), anchor="ma")
    save(img, os.path.join(ROOT, "screenshots", "4-tsunami.png"))


# -------------------------------------------------------------- icon
def make_icon():
    size = 512
    img = Image.new("RGB", (size, size), (24, 42, 92))
    draw = ImageDraw.Draw(img, "RGBA")
    # sky gradient
    for yy in range(size):
        f = yy / size
        draw.line([(0, yy), (size, yy)], fill=(int(24 + 40 * f), int(42 + 60 * f), int(92 + 60 * f)))
    # stars
    import random
    rng = random.Random(7)
    for _ in range(46):
        sx, sy = rng.randint(8, size - 8), rng.randint(8, 250)
        r = rng.choice([1.5, 2.2, 3.0])
        draw.ellipse([sx - r, sy - r, sx + r, sy + r], fill=(255, 250, 220))
    # ground, then the wordmark band (characters stand in front of it)
    draw.rectangle([0, 400, size, size], fill=(70, 160, 78))
    draw.rectangle([0, 400, size, 412], fill=(96, 190, 92))
    draw.rectangle([0, 436, size, size], fill=(22, 26, 44, 245))
    draw.ellipse([30, 420, 212, 444], fill=(0, 0, 0, 50))
    draw.ellipse([282, 418, 492, 446], fill=(0, 0, 0, 50))
    # the pair: avatar left, mascot right (same designs as the thumbnail)
    draw_avatar_2d(draw, 118, 440, 208)
    draw_mascot_2d(draw, 384, 438, 272)
    # wordmark across the bottom band
    draw.text((size / 2, 441), "BRAINROT", font=font(36), anchor="ma", fill=(255, 246, 205),
              stroke_width=5, stroke_fill=(30, 26, 60))
    draw.text((size / 2, 479), "TYCOON", font=font(21), anchor="ma", fill=(255, 205, 55),
              stroke_width=4, stroke_fill=(30, 26, 60))
    # chunky border
    draw.rounded_rectangle([5, 5, size - 5, size - 5], radius=30, outline=(255, 205, 55), width=9)
    path = os.path.join(os.path.dirname(ROOT), "brainrot-icon.png")
    img.save(path)
    print(path, os.path.getsize(path), "bytes")


if __name__ == "__main__":
    shot_thumbnail()
    shot_conveyor()
    shot_base()
    shot_tsunami()
    make_icon()
