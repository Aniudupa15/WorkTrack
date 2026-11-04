"""Renders the PunchIn icon set from punchin-mark.svg with headless Chrome.

    python assets/brand/render_icons.py   (from attendance_app/)

Outputs (PNG, transparent where noted):
  assets/images/logo.png              1024, rounded-square app mark (in-app logo)
  assets/images/icon_square.png       1024, full-bleed teal square (iOS / legacy)
  assets/images/icon_foreground.png   1024, white mark in the adaptive safe zone
  assets/images/splash_mark.png       1152, white mark for the splash screen
  ../store/icon-512.png               512,  Play Store icon (full bleed)
"""
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
BRAND = '#0F766E'
CHROME_CANDIDATES = [
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
]

mark = (ROOT / 'assets/brand/punchin-mark.svg').read_text()
inner = mark.split('>', 1)[1].rsplit('</svg>', 1)[0]  # drop the outer <svg>


def svg(size, background, scale, radius=0):
    """The mark scaled to `scale` of the canvas, centred, on `background`."""
    offset = (1 - scale) * 50
    bg = (
        f'<rect width="100" height="100" rx="{radius}" fill="{background}"/>'
        if background
        else ''
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 100 100">{bg}'
        f'<g transform="translate({offset} {offset}) scale({scale})">{inner}</g></svg>'
    )


ASSETS = {
    'assets/images/logo.png': (1024, BRAND, 1.0, 24),
    'assets/images/icon_square.png': (1024, BRAND, 1.0, 0),
    # Adaptive icons: flutter_launcher_icons insets the foreground by 16%,
    # which already puts the full-size mark inside the 66dp safe circle.
    'assets/images/icon_foreground.png': (1024, None, 1.0, 0),
    # Android 12 splash: 288dp canvas masked to a 192dp circle.
    'assets/images/splash_mark.png': (1152, None, 0.62, 0),
    '../store/icon-512.png': (512, BRAND, 1.0, 0),
}


def main():
    chrome = next(p for p in CHROME_CANDIDATES if pathlib.Path(p).exists())
    with tempfile.TemporaryDirectory() as tmp:
        for rel, (size, bg, scale, radius) in ASSETS.items():
            page = pathlib.Path(tmp) / 'page.html'
            page.write_text(
                '<html><body style="margin:0;background:transparent">'
                + svg(size, bg, scale, radius)
                + '</body></html>'
            )
            out = (ROOT / rel).resolve()
            out.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(
                [
                    chrome,
                    '--headless=new',
                    '--disable-gpu',
                    '--hide-scrollbars',
                    '--force-device-scale-factor=1',
                    '--default-background-color=00000000',
                    f'--window-size={size},{size}',
                    f'--screenshot={out}',
                    page.as_uri(),
                ],
                check=True,
                capture_output=True,
            )
            print('wrote', out.relative_to(ROOT.parent))


if __name__ == '__main__':
    main()
