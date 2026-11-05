"""Builds store/promo/punchin-promo.mp4 (1080x1920, ~30 s) from the store
screenshots: renders each captioned scene with headless Chrome, then joins
them with ffmpeg crossfades and a slow zoom.

Run: python store/src/render_promo.py
"""

import pathlib
import subprocess
import tempfile

from render_store import APP, CHROME, ROOT, mark

SHOTS = ROOT / 'store/screenshots'
OUT = ROOT / 'store/promo'
fonts = (APP / 'assets/fonts').as_uri()
W, H = 1080, 1920
SECONDS = 4.2
FADE = 0.6

BASE = f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: DM; src: url('{fonts}/DMSans-Bold.ttf'); font-weight: 700; }}
@font-face {{ font-family: DM; src: url('{fonts}/DMSans-Medium.ttf'); font-weight: 500; }}
html,body {{ margin:0; width:{W}px; height:{H}px; overflow:hidden; }}
body {{ font-family: DM, sans-serif; color:#fff; position:relative;
  background: radial-gradient(circle at 80% 10%, #14B8A6 0, transparent 40%),
              linear-gradient(160deg, #0F766E 0%, #134E4A 100%); }}
.grid {{ position:absolute; inset:0; opacity:.07;
  background-image: linear-gradient(#fff 1px, transparent 1px), linear-gradient(90deg, #fff 1px, transparent 1px);
  background-size: 60px 60px; }}
.cap {{ position:absolute; left:80px; right:80px; top:120px; }}
.kicker {{ font-size:34px; font-weight:500; opacity:.8; letter-spacing:1px; text-transform:uppercase; }}
h1 {{ margin:16px 0 0; font-size:76px; line-height:1.05; letter-spacing:-1.5px; font-weight:700; }}
.phone {{ position:absolute; left:50%; transform:translateX(-50%); top:470px; width:640px; height:1386px;
  border-radius:72px; background:#0b1514; padding:18px; box-shadow:0 40px 120px rgba(0,0,0,.45); }}
.phone img {{ width:100%; height:100%; object-fit:cover; object-position:top; border-radius:56px; display:block; }}
.center {{ position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; padding:0 90px; }}
.tile {{ width:260px; height:260px; border-radius:64px; background:rgba(255,255,255,.12); border:3px solid rgba(255,255,255,.25); }}
.tile svg {{ width:260px; height:260px; }}
.big {{ font-size:120px; font-weight:700; letter-spacing:-3px; margin-top:48px; }}
.sub {{ font-size:52px; font-weight:500; margin-top:20px; line-height:1.2; }}
.chips {{ margin-top:60px; display:flex; flex-direction:column; gap:22px; align-items:center; }}
.chip {{ font-size:40px; font-weight:500; padding:18px 36px; border-radius:999px; background:rgba(255,255,255,.14); border:2px solid rgba(255,255,255,.3); }}
.price {{ font-size:150px; font-weight:700; letter-spacing:-4px; }}
</style></head><body><div class="grid"></div>"""


def title():
    return BASE + f"""<div class="center"><div class="tile">{mark}</div>
<div class="big">PunchIn</div><div class="sub">Attendance your team can trust</div></div></body></html>"""


def phone(img, kicker, headline):
    return BASE + f"""<div class="cap"><div class="kicker">{kicker}</div><h1>{headline}</h1></div>
<div class="phone"><img src="{img.as_uri()}"></div></body></html>"""


def pricing():
    return BASE + """<div class="center"><div class="sub">Free for up to 5 people</div>
<div class="price">₹39</div><div class="sub">per person / month on Pro<br>14-day free trial · no card</div>
<div class="chips"><span class="chip">Multiple sites</span><span class="chip">Leave &amp; approvals</span><span class="chip">Payroll for Tally · Zoho · Keka</span></div></div></body></html>"""


def cta():
    return BASE + f"""<div class="center"><div class="tile">{mark}</div>
<div class="big">Get PunchIn</div><div class="sub">on Google Play<br>or in your browser</div>
<div class="chips"><span class="chip">Set up your company in 5 minutes</span></div></div></body></html>"""


# Captioned 1080x1920 phone frames double as Play Store screenshots
# (Play caps the aspect ratio at 2:1; raw captures are 1080x2400).
PLAY = [
    ('employee-home.png', 'For your staff', 'One tap to punch in'),
    ('punch-sheet.png', 'Geofenced', 'Only inside the work zone'),
    ('punch-success.png', 'Tamper-proof', 'Server time, GPS and selfie'),
    ('admin-today.png', 'For owners', 'Who’s in, late or absent today'),
    ('live-map.png', 'Every site', 'Your whole team on one map'),
    ('logs.png', 'No proxy punches', 'Flags tries from outside the zone'),
    ('reports.png', 'Month end', 'Reports and payroll export'),
    ('my-leaves.png', 'Leave', 'Balances, requests and approvals'),
]

SCENES = [
    ('title', title, None),
    ('punch', phone, ('employee-home.png', 'For your staff', 'Punch in only when you’re at work')),
    ('map', phone, ('punch-sheet.png', 'Geofenced', 'Server time. GPS checked. No proxy punches.')),
    ('admin', phone, ('admin-today.png', 'For owners', 'See who’s in across every site')),
    ('live', phone, ('live-map.png', 'Live map', 'Every site, every punch, one screen')),
    ('flag', phone, ('logs.png', 'Caught', 'Tries from outside the zone get flagged')),
    ('team', phone, ('invite.png', 'Onboard in minutes', 'Invite by WhatsApp, SMS or QR')),
    ('reports', phone, ('reports.png', 'Month end', 'Reports and payroll export')),
    ('pricing', pricing, None),
    ('cta', cta, None),
]


def render(html, out):
    with tempfile.TemporaryDirectory() as tmp:
        page = pathlib.Path(tmp) / 'p.html'
        page.write_text(html, encoding='utf-8')
        subprocess.run(
            [CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
             '--allow-file-access-from-files', '--force-device-scale-factor=1',
             f'--window-size={W},{H}', f'--screenshot={out}', page.as_uri()],
            check=True, capture_output=True,
        )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    frames = OUT / 'frames'
    frames.mkdir(exist_ok=True)
    pngs = []
    for name, fn, args in SCENES:
        if args:
            img = SHOTS / args[0]
            if not img.exists():
                print('skip', name, '(no', img.name + ')')
                continue
            html = fn(img, args[1], args[2])
        else:
            html = fn()
        out = frames / f'{len(pngs):02d}-{name}.png'
        render(html, out)
        pngs.append(out)
        print('scene', out.name)

    play = ROOT / 'store/play-screenshots'
    play.mkdir(exist_ok=True)
    for i, (img, kicker, headline) in enumerate(PLAY, 1):
        if (SHOTS / img).exists():
            render(phone(SHOTS / img, kicker, headline), play / f'{i:02d}-{img}')
            print('play', img)

    # Each still gets a gentle zoom, then they crossfade into each other.
    fps = 30
    inputs, filters = [], []
    for i, p in enumerate(pngs):
        inputs += ['-i', str(p)]
        n = int(SECONDS * fps)
        filters.append(
            f'[{i}:v]scale={W * 2}:{H * 2},zoompan=z=\'min(1+0.0006*on,1.06)\':'
            f'x=\'iw/2-(iw/zoom/2)\':y=\'ih/2-(ih/zoom/2)\':d={n}:s={W}x{H}:fps={fps},'
            f'format=yuv420p,setsar=1[v{i}]'
        )
    last = 'v0'
    for i in range(1, len(pngs)):
        offset = i * (SECONDS - FADE)
        filters.append(f'[{last}][v{i}]xfade=transition=fade:duration={FADE}:offset={offset:.2f}[x{i}]')
        last = f'x{i}'
    video = OUT / 'punchin-promo.mp4'
    subprocess.run(
        ['ffmpeg', '-y', *inputs, '-filter_complex', ';'.join(filters), '-map', f'[{last}]',
         '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p',
         '-movflags', '+faststart', str(video)],
        check=True, capture_output=True,
    )
    print('wrote', video)


if __name__ == '__main__':
    main()
