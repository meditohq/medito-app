from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parent
FONT = ROOT.parents[2] / 'assets/fonts/google-sans'
OUT = ROOT / 'upload'
OUT.mkdir(exist_ok=True)

def font(size, bold=False):
    return ImageFont.truetype(str(FONT / ('GoogleSans-Bold.ttf' if bold else 'GoogleSans-Regular.ttf')), size)

def ipad(source, name, title, subtitle, background):
    canvas = Image.new('RGB', (2752, 2064), background)
    draw = ImageDraw.Draw(canvas)
    draw.text((90, 130), 'medito', fill='white', font=font(68, True))
    draw.text((90, 240), 'ON iPAD', fill='#e5dcef', font=font(34))
    size = 110
    while max(draw.textlength(line, font=font(size, True)) for line in title.splitlines()) > 480:
        size -= 1
    draw.multiline_text((90, 650), title, fill='white', font=font(size, True), spacing=14)
    draw.multiline_text((90, 1170), subtitle, fill='#f3eef8', font=font(36), spacing=15)
    shot = Image.open(ROOT / 'raw' / source).convert('RGB')
    assert shot.size == (2752, 2064), shot.size
    shot.thumbnail((2032, 1524), Image.Resampling.LANCZOS)
    x, y = 640, (2064 - shot.height) // 2
    draw.rounded_rectangle((x-12, y-12, x+shot.width+12, y+shot.height+12), radius=28, fill='#100e16')
    canvas.paste(shot, (x, y))
    path = OUT / name
    canvas.save(path, optimize=True)
    return path

def widgets(source):
    canvas = Image.new('RGB', (1320, 2868), '#47306e')
    draw = ImageDraw.Draw(canvas)
    draw.text((90, 70), 'medito · iOS widgets', fill='#e4d9f4', font=font(44))
    draw.multiline_text((90, 170), 'Your practice,\non your Home Screen.', fill='white', font=font(96, True), spacing=8)
    draw.text((90, 405), 'Streak · consistency · continue', fill='#eee8f6', font=font(44))
    shot = Image.open(ROOT / 'raw' / source).convert('RGB')
    assert shot.size == (1320, 2868), shot.size
    # Native SwiftUI widget previews, cropped as a group; no simulated Home Screen.
    native = shot.crop((70, 750, 1250, 2160))
    canvas.paste(native, (70, 720))
    draw.multiline_text((90, 2320), 'Keep your streak in sight.\nPick up where you left off.', fill='white', font=font(54), spacing=18)
    path = OUT / 'medito-next-iPhone6.9-04-widgets.png'
    canvas.save(path, optimize=True)
    return path

if __name__ == '__main__':
    paths = [
        ipad('ipad-explore.png', 'medito-next-ipadPro129-01-explore.png', 'More room\nfor calm.', 'Explore meditation, sleep\nand mindfulness.', '#423064'),
        ipad('ipad-course.png', 'medito-next-ipadPro129-02-course.png', 'Learn at\nyour own\npace.', 'Follow the Medito course\non your larger screen.', '#235752'),
        ipad('ipad-player.png', 'medito-next-ipadPro129-03-player.png', 'Settle in.\nPress play.', 'Spacious playback controls\nfor your meditation.', '#293f69'),
    ]
    if (ROOT / 'raw' / 'iphone-widgets.png').exists():
        paths.append(widgets('iphone-widgets.png'))
    staging = ROOT / 'fastlane' / 'screenshots' / 'en-GB'
    staging.mkdir(parents=True, exist_ok=True)
    records = []
    for p in paths:
        im = Image.open(p)
        assert im.mode == 'RGB'
        assert p.stat().st_size < 10 * 1024 * 1024
        shutil.copyfile(p, staging / p.name)
        records.append({'filename': p.name, 'pixels': list(im.size), 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()})
        print(p.name, im.size, p.stat().st_size)
    (ROOT / 'manifest.json').write_text(json.dumps({'appId': '1500780518', 'sourceVersion': '2611.11.0', 'sourceBuild': '302489', 'sourceArtifact': 'GitHub Actions 43036413056 / medito-sim-app', 'locale': 'en-GB', 'status': 'Prepared for next release; no editable version draft exists', 'assets': records}, indent=2))
