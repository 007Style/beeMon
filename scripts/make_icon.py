#!/usr/bin/env python3
"""
Generate beeMon AppIcon.icns
Cute bee holding a clipboard with tiny stat lines.
"""

import os, subprocess, math
from PIL import Image, ImageDraw, ImageFilter

ROOT    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS  = os.path.join(ROOT, "Sources", "beeMon", "Assets")
ICONSET = os.path.join(ASSETS, "AppIcon.iconset")
ICNS    = os.path.join(ASSETS, "AppIcon.icns")
os.makedirs(ICONSET, exist_ok=True)

# ── palette ───────────────────────────────────────────────────────────────────
BG_TOP    = ( 22,  28,  48, 255)
BG_BOT    = ( 12,  14,  24, 255)
AMBER_HI  = (255, 210,  50, 255)
AMBER_LO  = (220, 140,  10, 255)
STRIPE    = ( 24,  16,   4, 255)
WING_F    = (200, 235, 255,  75)
WING_O    = (170, 220, 255, 180)
HEAD_C    = ( 30,  20,   5, 255)
EYE_W     = (245, 245, 245, 240)
EYE_K     = ( 15,  10,   5, 255)
EYE_SHINE = (255, 255, 255, 200)
CHEEK     = (255, 160, 100,  90)
CLIP_BG   = (245, 240, 225, 255)   # clipboard cream
CLIP_LINE = (180, 165, 130, 255)   # clipboard outline
CLIP_CLIP = (160, 160, 170, 255)   # metal clip
STAT_BLUE = ( 80, 180, 255, 255)
STAT_PURP = (170, 120, 255, 255)
STAT_MINT = ( 60, 220, 150, 255)
STINGER   = ( 50,  35,   8, 230)
SMILE     = ( 60,  35,   8, 200)

def blend(a, b, t):
    return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(4))

def ellipse_alpha_mask(S, cx, cy, rx, ry):
    m = Image.new("L", (S,S), 0)
    ImageDraw.Draw(m).ellipse([cx-rx, cy-ry, cx+rx, cy+ry], fill=255)
    return m

def draw_icon(S: int) -> Image.Image:
    img = Image.new("RGBA", (S,S), (0,0,0,0))
    d   = ImageDraw.Draw(img)

    # ── background: dark navy rounded rect with gradient ─────────────────────
    r = int(S * 0.20)
    # gradient: draw rows blending BG_TOP → BG_BOT
    bg = Image.new("RGBA", (S,S), (0,0,0,0))
    bgd = ImageDraw.Draw(bg)
    for y in range(S):
        c = blend(BG_TOP, BG_BOT, y/S)
        bgd.line([(0,y),(S,y)], fill=c)
    # mask to rounded rect
    mask = Image.new("L", (S,S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0,0,S-1,S-1], radius=r, fill=255)
    img.paste(bg, mask=mask)

    # subtle inner highlight top edge
    hi = Image.new("RGBA", (S,S), (0,0,0,0))
    ImageDraw.Draw(hi).rounded_rectangle(
        [1, 1, S-2, S//3], radius=r, fill=(80, 90, 140, 28))
    img.alpha_composite(hi)

    # ── layout anchors ────────────────────────────────────────────────────────
    # Bee body centred slightly left, clipboard to the right/below
    bcx = S * 0.42   # bee centre x
    bcy = S * 0.48   # bee centre y
    bw  = S * 0.185  # body half-width
    bh  = S * 0.240  # body half-height

    # ── soft glow ─────────────────────────────────────────────────────────────
    gl = Image.new("RGBA", (S,S), (0,0,0,0))
    gr = int(S*0.32)
    ImageDraw.Draw(gl).ellipse([bcx-gr, bcy-gr, bcx+gr, bcy+gr],
                               fill=(60,195,100,45))
    gl = gl.filter(ImageFilter.GaussianBlur(S*0.09))
    img.alpha_composite(gl)

    # ── clipboard (drawn first so bee arm overlaps it) ────────────────────────
    # clipboard rect
    cbx = S * 0.645  # clipboard centre x
    cby = S * 0.575  # clipboard centre y
    cbw = S * 0.200  # half width
    cbh = S * 0.245  # half height
    cb_r = max(2, int(S*0.025))

    cb = Image.new("RGBA", (S,S), (0,0,0,0))
    cbd = ImageDraw.Draw(cb)
    # shadow
    cbd.rounded_rectangle(
        [cbx-cbw+S*0.008, cby-cbh+S*0.010,
         cbx+cbw+S*0.008, cby+cbh+S*0.010],
        radius=cb_r, fill=(0,0,0,80))
    # board
    cbd.rounded_rectangle(
        [cbx-cbw, cby-cbh, cbx+cbw, cby+cbh],
        radius=cb_r, fill=CLIP_BG, outline=CLIP_LINE,
        width=max(1, S//120))
    # clip (top metal tab)
    clip_w = cbw * 0.40
    clip_h = cbh * 0.16
    clip_x = cbx
    clip_y = cby - cbh
    cbd.rounded_rectangle(
        [clip_x-clip_w, clip_y-clip_h*0.8,
         clip_x+clip_w, clip_y+clip_h*0.8],
        radius=max(1, int(S*0.018)),
        fill=CLIP_CLIP, outline=(120,120,130,255),
        width=max(1, S//150))
    # hole in clip
    hole_r = max(1, int(S*0.016))
    cbd.ellipse([clip_x-hole_r, clip_y-hole_r,
                 clip_x+hole_r, clip_y+hole_r],
                fill=(180,180,190,255))

    # stat lines on clipboard
    line_x0 = cbx - cbw*0.72
    line_x1_full = cbx + cbw*0.72
    line_y_start = cby - cbh*0.44
    line_gap = cbh * 0.28
    bar_h = max(2, int(S*0.022))

    # three coloured bar-chart style stat rows
    bars = [
        (STAT_BLUE,  0.82),   # CPU — long bar
        (STAT_PURP,  0.55),   # Mem — medium bar
        (STAT_MINT,  0.68),   # Net — medium-long
    ]
    for i, (col, fill_frac) in enumerate(bars):
        ly = line_y_start + i * line_gap
        # track background
        cbd.rounded_rectangle(
            [line_x0, ly, line_x1_full, ly+bar_h],
            radius=max(1, bar_h//2),
            fill=(200, 195, 178, 255))
        # filled portion
        fx = line_x0 + (line_x1_full - line_x0) * fill_frac
        cbd.rounded_rectangle(
            [line_x0, ly, fx, ly+bar_h],
            radius=max(1, bar_h//2),
            fill=col)

    # tiny label dots to the left of each bar
    dot_r = max(1, int(S*0.013))
    for i, (col, _) in enumerate(bars):
        ly = line_y_start + i * line_gap + bar_h//2
        cbd.ellipse([line_x0-dot_r*2-dot_r, ly-dot_r,
                     line_x0-dot_r*2+dot_r, ly+dot_r], fill=col)

    img.alpha_composite(cb)

    # ── wings (behind body) ───────────────────────────────────────────────────
    def wing(pts, blur=True):
        wl = Image.new("RGBA", (S,S), (0,0,0,0))
        ImageDraw.Draw(wl).polygon(pts, fill=WING_F, outline=WING_O)
        if blur:
            wl = wl.filter(ImageFilter.GaussianBlur(S*0.009))
        img.alpha_composite(wl)

    wing([  # top-left wing
        (bcx,          bcy - bh*0.25),
        (bcx - S*0.28, bcy - bh*1.05),
        (bcx - S*0.33, bcy - bh*0.35),
        (bcx - S*0.15, bcy + bh*0.05),
    ])
    wing([  # top-right wing (smaller — clipboard side)
        (bcx,          bcy - bh*0.25),
        (bcx + S*0.20, bcy - bh*0.90),
        (bcx + S*0.24, bcy - bh*0.28),
        (bcx + S*0.10, bcy + bh*0.05),
    ])
    wing([  # lower-left
        (bcx - S*0.04, bcy + bh*0.02),
        (bcx - S*0.25, bcy - bh*0.05),
        (bcx - S*0.26, bcy + bh*0.30),
        (bcx - S*0.08, bcy + bh*0.36),
    ])
    wing([  # lower-right
        (bcx + S*0.04, bcy + bh*0.02),
        (bcx + S*0.18, bcy - bh*0.05),
        (bcx + S*0.19, bcy + bh*0.30),
        (bcx + S*0.06, bcy + bh*0.36),
    ])

    # ── body ──────────────────────────────────────────────────────────────────
    body = Image.new("RGBA", (S,S), (0,0,0,0))
    bd   = ImageDraw.Draw(body)
    bd.ellipse([bcx-bw, bcy-bh, bcx+bw, bcy+bh], fill=AMBER_LO)
    # top-half brighter
    top = Image.new("RGBA", (S,S), (0,0,0,0))
    ImageDraw.Draw(top).ellipse([bcx-bw, bcy-bh, bcx+bw, bcy], fill=AMBER_HI)
    body.alpha_composite(top)

    # stripes clipped to body ellipse
    bmask = ellipse_alpha_mask(S, int(bcx), int(bcy), int(bw), int(bh))
    band_h = bh * 0.11
    for fy in [0.27, 0.50, 0.71]:
        sy = bcy - bh + fy * bh*2
        sl = Image.new("RGBA", (S,S), (0,0,0,0))
        ImageDraw.Draw(sl).ellipse(
            [bcx-bw*0.92, sy-band_h, bcx+bw*0.92, sy+band_h], fill=STRIPE)
        sl.putalpha(Image.composite(sl.split()[3],
                                    Image.new("L",(S,S),0), bmask))
        body.alpha_composite(sl)

    # sheen
    shine = Image.new("RGBA", (S,S), (0,0,0,0))
    ImageDraw.Draw(shine).ellipse(
        [bcx-bw*0.48, bcy-bh*0.80, bcx+bw*0.48, bcy-bh*0.15],
        fill=(255,245,195,80))
    shine = shine.filter(ImageFilter.GaussianBlur(S*0.014))
    body.alpha_composite(shine)

    lw = max(1, S//70)
    bd.ellipse([bcx-bw, bcy-bh, bcx+bw, bcy+bh],
               outline=(20,12,2,200), width=lw)
    img.alpha_composite(body)

    # ── arm holding clipboard ─────────────────────────────────────────────────
    arm = Image.new("RGBA", (S,S), (0,0,0,0))
    ad  = ImageDraw.Draw(arm)
    arm_w = max(2, int(S*0.038))
    # arm goes from right side of body to clipboard left edge
    ax0, ay0 = bcx + bw*0.70, bcy + bh*0.10
    ax1, ay1 = cbx - cbw*0.85, cby - cbh*0.10
    ad.line([(ax0,ay0),(ax1,ay1)], fill=AMBER_LO, width=arm_w)
    # round the joints
    jr = arm_w//2
    ad.ellipse([ax0-jr, ay0-jr, ax0+jr, ay0+jr], fill=AMBER_LO)
    ad.ellipse([ax1-jr, ay1-jr, ax1+jr, ay1+jr], fill=AMBER_LO)
    img.alpha_composite(arm)

    # ── head ──────────────────────────────────────────────────────────────────
    hr  = bw * 0.62
    hcx = bcx
    hcy = bcy - bh - hr * 0.48
    head = Image.new("RGBA", (S,S), (0,0,0,0))
    hd   = ImageDraw.Draw(head)
    hd.ellipse([hcx-hr, hcy-hr, hcx+hr, hcy+hr], fill=HEAD_C)

    # cheeks
    ck_r = hr * 0.30
    for sign in [-1, 1]:
        ck = Image.new("RGBA", (S,S), (0,0,0,0))
        ImageDraw.Draw(ck).ellipse(
            [hcx+sign*hr*0.48-ck_r, hcy+hr*0.20-ck_r,
             hcx+sign*hr*0.48+ck_r, hcy+hr*0.20+ck_r], fill=CHEEK)
        ck = ck.filter(ImageFilter.GaussianBlur(S*0.014))
        head.alpha_composite(ck)

    # eyes
    eo = hr * 0.34
    er = max(2, int(hr*0.26))
    pr = max(1, int(er*0.52))
    sr = max(1, int(er*0.20))
    for sign in [-1, 1]:
        ex = hcx + sign*eo
        ey = hcy - hr*0.06
        hd.ellipse([ex-er, ey-er, ex+er, ey+er], fill=EYE_W)
        hd.ellipse([ex-pr, ey-pr, ex+pr, ey+pr], fill=EYE_K)
        # shine dot
        hd.ellipse([ex+pr*0.2, ey-pr*0.6,
                    ex+pr*0.2+sr, ey-pr*0.6+sr], fill=EYE_SHINE)

    # smile
    smile_r = int(hr*0.38)
    smile_box = [hcx-smile_r, hcy+hr*0.10,
                 hcx+smile_r, hcy+hr*0.10+smile_r*1.1]
    hd.arc(smile_box, start=10, end=170,
           fill=SMILE, width=max(1, int(S*0.018)))

    # antennae
    aw2 = max(1, S//85)
    for sign in [-1, 1]:
        bax = hcx + sign*hr*0.30
        bay = hcy - hr*0.72
        tax = hcx + sign*hr*0.72
        tay = hcy - hr*1.58
        hd.line([(bax,bay),(tax,tay)], fill=(30,20,5,220), width=aw2)
        tr = max(2, S//46)
        hd.ellipse([tax-tr,tay-tr,tax+tr,tay+tr], fill=AMBER_HI)

    img.alpha_composite(head)

    # ── stinger ───────────────────────────────────────────────────────────────
    st = Image.new("RGBA", (S,S), (0,0,0,0))
    ImageDraw.Draw(st).polygon([
        (bcx-S*0.034, bcy+bh-S*0.008),
        (bcx+S*0.034, bcy+bh-S*0.008),
        (bcx,         bcy+bh+S*0.075),
    ], fill=STINGER)
    img.alpha_composite(st)

    # ── vignette ──────────────────────────────────────────────────────────────
    vig = Image.new("RGBA", (S,S), (0,0,0,0))
    vd  = ImageDraw.Draw(vig)
    for i in range(12):
        t   = i/12
        ins = int(S*t*0.46)
        alp = int(50*(1-t)**2)
        rad = max(2, int(r*(1-t*0.5)))
        vd.rounded_rectangle([ins,ins,S-ins,S-ins],
                              radius=rad, outline=(0,0,0,alp), width=1)
    img.alpha_composite(vig)

    return img


SIZES = [16, 32, 64, 128, 256, 512, 1024]
print("🎨  Rendering bee-with-clipboard icon…")
for sz in SIZES:
    for scale, sfx in [(1,""), (2,"@2x")]:
        px   = sz*scale
        name = f"icon_{sz}x{sz}{sfx}.png"
        draw_icon(px).save(os.path.join(ICONSET, name), "PNG")
        print(f"   {name}  ({px}×{px})")

print("📦  Packing .icns…")
subprocess.run(["iconutil","-c","icns", ICONSET,"-o", ICNS], check=True)
print(f"✅  {ICNS}")
