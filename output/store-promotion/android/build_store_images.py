from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

ROOT = Path(__file__).resolve().parent
FONT = ROOT.parents[2] / 'assets/fonts/google-sans'
OUT = ROOT / 'upload'
OUT.mkdir(exist_ok=True)

def font(size, bold=False):
    return ImageFont.truetype(str(FONT / ('GoogleSans-Bold.ttf' if bold else 'GoogleSans-Regular.ttf')), size)

def tablet(source, name, title, subtitle, background):
    canvas = Image.new('RGB', (3200, 1800), background)
    draw = ImageDraw.Draw(canvas)
    draw.text((110, 110), 'medito', fill='white', font=font(72, True))
    draw.text((110, 226), 'ON ANDROID TABLET', fill='#ded3ef', font=font(34))
    title_size = 116
    while max(draw.textlength(line, font=font(title_size, True)) for line in title.splitlines()) > 560:
        title_size -= 1
    draw.multiline_text((110, 520), title, fill='white', font=font(title_size, True), spacing=12)
    draw.multiline_text((110, 1050), subtitle, fill='#f2edf8', font=font(43), spacing=16)
    shot = Image.open(ROOT / 'raw' / source).convert('RGB')
    shot.thumbnail((2416, 1510), Image.Resampling.LANCZOS)
    x, y = 730, (1800 - shot.height) // 2
    draw.rounded_rectangle((x-12, y-12, x+shot.width+12, y+shot.height+12), radius=30, fill='#100e16')
    canvas.paste(shot, (x, y))
    path = OUT / name
    canvas.save(path, optimize=True)
    return path

def phone(source, name, title, subtitle):
    canvas = Image.new('RGB', (1080,1920), '#47306e')
    draw = ImageDraw.Draw(canvas)
    draw.text((76,56), 'medito · Android widgets', fill='#e4d9f4', font=font(34))
    draw.multiline_text((76,134), title, fill='white', font=font(80,True), spacing=4)
    draw.text((76,330), subtitle, fill='#eee8f6', font=font(32))
    shot=Image.open(ROOT/'raw'/source).convert('RGB')
    shot.thumbnail((820,1460),Image.Resampling.LANCZOS)
    x,y=(1080-shot.width)//2,410
    draw.rounded_rectangle((x-10,y-10,x+shot.width+10,y+shot.height+10),radius=30,fill='#100e16')
    canvas.paste(shot,(x,y))
    path=OUT/name
    canvas.save(path,optimize=True)
    return path

if __name__ == '__main__':
    files = [
        tablet('tablet-explore.png','01-tablet-explore.png','More room\nfor calm.','Explore meditation, sleep\nand mindfulness.','#423064'),
        tablet('tablet-course.png','02-tablet-course.png','Learn at\nyour own\npace.','Follow the Medito course\non your larger screen.','#235752'),
        tablet('tablet-player.png','03-tablet-player.png','Settle in.\nPress play.','Spacious playback controls\nfor your meditation.','#293f69'),
    ]
    for source, name, title, subtitle in [
        ('phone-widgets.png','04-android-widgets.png','Widgets for your\nhome screen.','Streak · consistency · continue'),
    ]:
        if (ROOT/'raw'/source).exists():
            files.append(phone(source,name,title,subtitle))
    for p in files:
        im=Image.open(p)
        assert im.mode=='RGB' and p.stat().st_size<8*1024*1024
        assert im.width*9==im.height*16 or im.width*16==im.height*9
        print(p.name,im.size,p.stat().st_size)
    (ROOT/'manifest.json').write_text(json.dumps({'appVersion':'2611.11.0','versionCode':302489,'tabletGallery':['7-inch','10-inch'],'assets':[str(p) for p in files]},indent=2))
