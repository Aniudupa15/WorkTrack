"""Builds the PunchIn advertisement in two shapes from the real app screenshots:

  store/promo/punchin-ad-16x9.mp4  (1920x1080, website / YouTube / Play listing)
  store/promo/punchin-ad-9x16.mp4  (1080x1920, WhatsApp Status / Reels / Shorts)

Scenes are rendered with headless Chrome, joined with ffmpeg crossfades and a
slow zoom, and scored with an original music bed synthesised here (no
third-party audio, so no licensing).

Run: python store/src/render_ad.py
"""

import pathlib
import subprocess
import tempfile
import wave

import numpy as np

from render_store import APP, CHROME, ROOT, mark

SHOTS = ROOT / 'store/screenshots'
OUT = ROOT / 'store/promo'
fonts = (APP / 'assets/fonts').as_uri()
FPS = 30
FADE = 0.5

PLAY_URL = 'Google Play: PunchIn Staff Attendance'
WEB_URL = 'aniudupa15.github.io/WorkTrack'

FEATURES = [
    ('employee-home.png', 'For your staff', 'One tap to punch in.<br>Only when they’re<br>at work.'),
    ('punch-sheet.png', 'Geofenced &amp; tamper-proof', 'GPS checked.<br>Server time.<br>No proxy punches.'),
    ('live-map.png', 'For owners', 'Every site, live,<br>on one screen.'),
    ('logs.png', 'Caught', 'Tries from outside<br>the site get flagged.'),
    ('reports.png', 'Month end in minutes', 'Reports and payroll<br>for Tally, Zoho<br>and Keka.'),
]


def css(w, h, landscape):
    big = 92 if landscape else 96
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: DM; src: url('{fonts}/DMSans-Bold.ttf'); font-weight: 700; }}
@font-face {{ font-family: DM; src: url('{fonts}/DMSans-Medium.ttf'); font-weight: 500; }}
html,body {{ margin:0; width:{w}px; height:{h}px; overflow:hidden; }}
body {{ font-family: DM, sans-serif; color:#fff; position:relative;
  background: radial-gradient(circle at 85% 12%, #14B8A6 0, transparent 42%),
              radial-gradient(circle at 10% 95%, #0D9488 0, transparent 35%),
              linear-gradient(150deg, #0F766E 0%, #134E4A 100%); }}
body.dark {{ background: radial-gradient(circle at 50% 30%, #1E293B 0, #020617 75%); }}
.grid {{ position:absolute; inset:0; opacity:.06;
  background-image: linear-gradient(#fff 1px, transparent 1px), linear-gradient(90deg, #fff 1px, transparent 1px);
  background-size: 64px 64px; }}
.center {{ position:absolute; inset:0; display:flex; flex-direction:column; align-items:center;
  justify-content:center; text-align:center; padding:0 {120 if landscape else 80}px; }}
.kicker {{ font-size:{34 if landscape else 38}px; font-weight:500; letter-spacing:3px; text-transform:uppercase; color:#99F6E4; }}
h1 {{ margin:18px 0 0; font-size:{big}px; line-height:1.04; letter-spacing:-2px; font-weight:700; }}
.sub {{ font-size:{44 if landscape else 50}px; font-weight:500; line-height:1.25; margin-top:26px; opacity:.92; }}
.tile {{ width:{220 if landscape else 260}px; height:{220 if landscape else 260}px; border-radius:56px;
  background:rgba(255,255,255,.12); border:3px solid rgba(255,255,255,.25); }}
.tile svg {{ width:100%; height:100%; }}
.word {{ font-size:{150 if landscape else 140}px; font-weight:700; letter-spacing:-4px; margin-top:36px; }}
.chips {{ display:flex; flex-wrap:wrap; gap:18px; justify-content:center; margin-top:44px; max-width:{1500 if landscape else 900}px; }}
.chip {{ font-size:{36 if landscape else 40}px; font-weight:500; padding:16px 34px; border-radius:999px;
  background:rgba(255,255,255,.14); border:2px solid rgba(255,255,255,.3); }}

.rs {{ font-family:'Segoe UI', 'Nirmala UI', sans-serif; font-weight:600; }}
.price {{ font-size:{200 if landscape else 210}px; font-weight:700; letter-spacing:-6px; line-height:1; }}
.btn {{ margin-top:40px; font-size:{44 if landscape else 48}px; font-weight:700; color:#0F766E; background:#fff;
  padding:24px 56px; border-radius:24px; box-shadow:0 20px 60px rgba(0,0,0,.25); }}
.url {{ margin-top:26px; font-size:{36 if landscape else 40}px; font-weight:500; opacity:.9; }}
.phone {{ border-radius:64px; background:#0b1514; padding:16px; box-shadow:0 40px 120px rgba(0,0,0,.45); }}
.phone img {{ width:100%; height:100%; object-fit:cover; object-position:top; border-radius:50px; display:block; }}
.split {{ position:absolute; inset:0; display:flex; align-items:center; gap:110px; padding:0 150px; }}
.split .copy {{ flex:1; }}
.split .phone {{ width:430px; height:930px; flex:none; }}
.stack .cap {{ position:absolute; left:80px; right:80px; top:130px; }}
.stack .phone {{ position:absolute; left:50%; transform:translateX(-50%); top:560px; width:600px; height:1300px; }}
</style></head>"""


def scenes(landscape):
    w, h = (1920, 1080) if landscape else (1080, 1920)
    head = css(w, h, landscape)

    def page(body, dark=False):
        return head + f'<body class="{"dark" if dark else ""}"><div class="grid"></div>{body}</body></html>'

    out = [
        ('hook', 3.6, page(
            '<div class="center"><div class="kicker">Security · Housekeeping · Field teams</div>'
            '<h1>Still taking attendance<br>on paper and phone calls?</h1>'
            '<div class="sub">Proxy punches. Late guards. Month-end chaos.</div></div>', dark=True)),
        ('logo', 3.0, page(
            f'<div class="center"><div class="tile">{mark}</div><div class="word">PunchIn</div>'
            '<div class="sub">Attendance your team can’t fake.</div></div>')),
    ]
    for img, kicker, headline in FEATURES:
        src = (SHOTS / img).as_uri()
        if landscape:
            body = (f'<div class="split"><div class="copy"><div class="kicker">{kicker}</div><h1>{headline}</h1></div>'
                    f'<div class="phone"><img src="{src}"></div></div>')
        else:
            body = (f'<div class="stack"><div class="cap"><div class="kicker">{kicker}</div><h1>{headline}</h1></div>'
                    f'<div class="phone"><img src="{src}"></div></div>')
        out.append((img.split('.')[0], 3.8, page(body)))
    out += [
        ('who', 3.6, page(
            '<div class="center"><div class="kicker">Built for teams that work at many places</div>'
            '<div class="chips"><span class="chip">Security agencies</span><span class="chip">Housekeeping &amp; facility</span>'
            '<span class="chip">Field service</span><span class="chip">Construction sites</span>'
            '<span class="chip">Packers &amp; movers</span><span class="chip">Shops &amp; offices</span></div>'
            '<div class="sub">Invite your team by WhatsApp, SMS or QR.<br>Set up in 5 minutes.</div></div>')),
        ('pricing', 4.0, page(
            '<div class="center"><div class="kicker">Simple pricing</div><div class="sub">Free for up to 5 people</div>'
            '<div class="price"><span class="rs">₹</span>39</div><div class="sub">per person / month on Pro (yearly)<br>14-day free trial · no card needed</div></div>')),
        ('cta', 5.0, page(
            f'<div class="center"><div class="tile">{mark}</div><h1>Try PunchIn free today</h1>'
            '<div class="btn">Get it on Google Play</div>'
            f'<div class="url">Search “PunchIn Staff Attendance” · {WEB_URL}</div></div>')),
    ]
    return out, w, h


def render(html, out, w, h):
    with tempfile.TemporaryDirectory() as tmp:
        page = pathlib.Path(tmp) / 'p.html'
        page.write_text(html, encoding='utf-8')
        subprocess.run(
            [CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
             '--allow-file-access-from-files', '--force-device-scale-factor=1',
             f'--window-size={w},{h}', f'--screenshot={out}', page.as_uri()],
            check=True, capture_output=True,
        )


def music(seconds, path, sr=44100):
    """A calm, upbeat bed: soft pad chords (Am F C G) with a light pluck
    arpeggio and a gentle pulse, 96 bpm. Generated here, so it's ours."""
    t = np.arange(int(seconds * sr)) / sr
    bpm = 96
    beat = 60 / bpm
    bar = 4 * beat
    note = lambda n: 440 * 2 ** ((n - 69) / 12)
    chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]  # Am F C G
    out = np.zeros_like(t)
    idx = (t // bar).astype(int) % 4
    # Pad: three detuned sines per chord tone, crossfaded at bar lines.
    for ci, ch in enumerate(chords):
        mask = (idx == ci).astype(float)
        env = np.convolve(mask, np.ones(2000) / 2000, mode='same')
        tone = sum(np.sin(2 * np.pi * note(n) * t) + 0.5 * np.sin(2 * np.pi * note(n) * 1.003 * t)
                   for n in ch)
        out += 0.10 * env * tone
    # Pluck arpeggio on eighth notes, one octave up.
    step = beat / 2
    k = (t // step).astype(int)
    local = t - k * step
    decay = np.exp(-local * 7)
    for ci, ch in enumerate(chords):
        mask = (idx == ci)
        tones = [note(n + 12) for n in ch + [ch[1]]]
        f = np.array(tones)[k % 4]
        out += 0.16 * mask * decay * np.sin(2 * np.pi * f * local)
    # Soft pulse on each beat (low sine thump).
    kb = (t // beat).astype(int)
    lb = t - kb * beat
    out += 0.22 * np.exp(-lb * 18) * np.sin(2 * np.pi * 55 * lb)
    fade = np.minimum(1, np.minimum(t / 1.0, (seconds - t) / 2.0))
    out *= np.clip(fade, 0, 1)
    out = out / np.max(np.abs(out)) * 0.5
    data = (out * 32767).astype(np.int16)
    stereo = np.column_stack([data, data]).ravel()
    with wave.open(str(path), 'wb') as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(stereo.tobytes())


def build(landscape):
    tag = '16x9' if landscape else '9x16'
    items, w, h = scenes(landscape)
    frames = OUT / f'ad-frames-{tag}'
    frames.mkdir(parents=True, exist_ok=True)
    inputs, filters, durs = [], [], []
    for i, (name, dur, html) in enumerate(items):
        png = frames / f'{i:02d}-{name}.png'
        render(html, png, w, h)
        inputs += ['-i', str(png)]
        n = int(dur * FPS)
        filters.append(
            f"[{i}:v]scale={w * 2}:{h * 2},zoompan=z='min(1+0.0007*on,1.07)':"
            f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={n}:s={w}x{h}:fps={FPS},"
            f"format=yuv420p,setsar=1[v{i}]"
        )
        durs.append(dur)
    last, offset = 'v0', 0.0
    for i in range(1, len(items)):
        offset += durs[i - 1] - FADE
        filters.append(f'[{last}][v{i}]xfade=transition=fade:duration={FADE}:offset={offset:.2f}[x{i}]')
        last = f'x{i}'
    total = sum(durs) - FADE * (len(durs) - 1)
    wav = frames / 'music.wav'
    music(total, wav)
    video = OUT / f'punchin-ad-{tag}.mp4'
    subprocess.run(
        ['ffmpeg', '-y', *inputs, '-i', str(wav), '-filter_complex', ';'.join(filters),
         '-map', f'[{last}]', '-map', f'{len(items)}:a', '-c:v', 'libx264', '-preset', 'medium',
         '-crf', '21', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '160k', '-shortest',
         '-movflags', '+faststart', str(video)],
        check=True, capture_output=True,
    )
    print('wrote', video, f'{total:.1f}s')


if __name__ == '__main__':
    build(landscape=True)
    build(landscape=False)
