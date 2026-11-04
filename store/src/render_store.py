"""Renders the Play Store feature graphic (1024x500) with headless Chrome.

Run: python store/src/render_store.py
"""

import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]  # WorkTrack/
APP = ROOT / 'attendance_app'
CHROME = next(
    p
    for p in [
        r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    ]
    if pathlib.Path(p).exists()
)

mark = (APP / 'assets/brand/punchin-mark.svg').read_text()
fonts = (APP / 'assets/fonts').as_uri()

FEATURE = f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family: DM; src: url('{fonts}/DMSans-Bold.ttf'); font-weight: 700; }}
@font-face {{ font-family: DM; src: url('{fonts}/DMSans-Medium.ttf'); font-weight: 500; }}
html,body {{ margin:0; width:1024px; height:500px; overflow:hidden; }}
body {{ font-family: DM, sans-serif; color:#fff;
  background: radial-gradient(circle at 85% 20%, #14B8A6 0, transparent 45%),
              linear-gradient(135deg, #0F766E 0%, #115E59 100%); position:relative; }}
.grid {{ position:absolute; inset:0; opacity:.08;
  background-image: linear-gradient(#fff 1px, transparent 1px), linear-gradient(90deg, #fff 1px, transparent 1px);
  background-size: 40px 40px; }}
.tile {{ position:absolute; left:72px; top:150px; width:200px; height:200px; border-radius:48px;
  background:rgba(255,255,255,.12); border:2px solid rgba(255,255,255,.25); }}
.tile svg {{ width:200px; height:200px; }}
.copy {{ position:absolute; left:320px; top:132px; right:40px; }}
h1 {{ margin:0; font-size:84px; font-weight:700; letter-spacing:-2px; line-height:1; }}
.tag {{ margin-top:18px; font-size:34px; font-weight:500; line-height:1.15; }}
.chips {{ margin-top:26px; display:flex; gap:10px; flex-wrap:wrap; }}
.chip {{ font-size:19px; font-weight:500; padding:8px 16px; border-radius:999px;
  background:rgba(255,255,255,.14); border:1px solid rgba(255,255,255,.28); }}
.zone {{ position:absolute; right:-80px; bottom:-120px; width:360px; height:360px; border-radius:50%;
  border:3px dashed rgba(255,255,255,.25); background:rgba(255,255,255,.05); }}
</style></head><body>
<div class="grid"></div><div class="zone"></div>
<div class="tile">{mark}</div>
<div class="copy">
  <h1>PunchIn</h1>
  <div class="tag">Attendance your team can trust</div>
  <div class="chips"><span class="chip">Geofenced punch-in</span><span class="chip">Multiple sites</span><span class="chip">Payroll export</span></div>
</div>
</body></html>"""


def shot(html, out, w, h):
    with tempfile.TemporaryDirectory() as tmp:
        page = pathlib.Path(tmp) / 'page.html'
        page.write_text(html, encoding='utf-8')
        subprocess.run(
            [
                CHROME,
                '--headless=new',
                '--disable-gpu',
                '--hide-scrollbars',
                '--allow-file-access-from-files',
                '--force-device-scale-factor=1',
                f'--window-size={w},{h}',
                f'--screenshot={out}',
                page.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
    print('wrote', out)


if __name__ == '__main__':
    shot(FEATURE, ROOT / 'store/feature-graphic.png', 1024, 500)
