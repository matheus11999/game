"""Original, reproducible pixel sprites and terrain; no external art downloads."""
from PIL import Image, ImageDraw
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets'
OUT.mkdir(exist_ok=True)
PAL = {'outline':'#192739','cream':'#fff0cc','eye':'#101b2a'}
sheet = Image.new('RGBA', (32*6,32*4))

def creature(i, frame):
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    o=PAL['outline']; eye=PAL['eye'];cream=PAL['cream']
    # Each pixel shape is intentionally authored on a 32x32 grid.
    if i==0:
        d.polygon([(4,17),(2,12),(5,8),(9,11),(10,19)],fill='#f4cc70',outline=o)
        d.polygon([(5,12),(3,7),(6,4),(9,10)],fill='#ef9859',outline=o)
        d.rectangle((10,17,25,26),fill='#bd603e',outline=o)
        d.polygon([(15,19),(12,10),(14,3),(19,8),(25,4),(27,12),(25,22)],fill='#efa761',outline=o)
        d.polygon([(14,4),(15,10),(18,8)],fill='#5b3e48');d.polygon([(25,5),(22,9),(26,10)],fill='#5b3e48')
        d.rectangle((16,15,17,17),fill=eye);d.rectangle((23,14,24,16),fill=eye)
        d.rectangle((18,19,24,21),fill=cream);d.point((22,19),fill=eye)
        d.rectangle((12,26,15,28),fill=o);d.rectangle((22,26,25,28),fill=o)
    elif i==1:
        d.rectangle((5,22,9,27),fill='#69a580',outline=o);d.rectangle((21,22,25,27),fill='#69a580',outline=o)
        d.ellipse((4,11,25,25),fill='#427965',outline=o);d.ellipse((5,7,23,22),fill='#559e77',outline=o)
        d.rectangle((9,9,18,13),fill='#92d88c');d.rectangle((8,15,13,18),fill='#78bc83');d.rectangle((16,14,21,19),fill='#386c60')
        d.rectangle((12,3,15,9),fill='#94d99b');d.rectangle((10,5,18,7),fill='#aee8a1');d.rectangle((17,4,20,6),fill='#dab374')
        d.ellipse((21,15,30,24),fill='#a4dda2',outline=o);d.rectangle((26,17,27,19),fill=eye);d.point((29,21),fill=eye)
    elif i==2:
        spread=1 if frame%2 else 0
        d.polygon([(13,14),(4,6+spread),(1,12),(3,22),(12,20)],fill='#b599df',outline=o)
        d.polygon([(18,14),(27,5+spread),(31,11),(29,23),(19,20)],fill='#c8a7ed',outline=o)
        d.rectangle((4,12,8,16),fill='#efd2e4');d.rectangle((23,11,27,15),fill='#efd2e4')
        d.polygon([(12,19),(5,22),(9,28),(14,24)],fill='#817cb8',outline=o)
        d.polygon([(19,19),(26,23),(23,28),(17,25)],fill='#817cb8',outline=o)
        d.ellipse((12,9,20,24),fill='#f5deb9',outline=o)
        d.line((14,9,11,4),fill=o);d.line((18,9,21,4),fill=o);d.rectangle((10,3,12,5),fill='#94e1c4');d.rectangle((20,3,22,5),fill='#94e1c4')
        d.rectangle((14,13,14,15),fill=eye);d.rectangle((18,13,18,15),fill=eye)
    elif i==3:
        d.polygon([(7,19),(1,15),(3,12),(9,15)],fill='#73c5d7',outline=o)
        d.rectangle((9,24,12,27),fill='#499bb8');d.rectangle((21,24,24,27),fill='#499bb8')
        d.ellipse((6,10,27,26),fill='#85d7dc',outline=o)
        for x,y in [(5,8),(10,5),(22,5),(28,9)]:d.rectangle((x,y,x+2,y+7),fill='#b9a4e2',outline=o)
        d.rectangle((10,16,12,18),fill=eye);d.rectangle((21,16,23,18),fill=eye);d.line((15,21,19,21),fill=eye)
        d.rectangle((11,20,13,21),fill='#d6b8e5');d.rectangle((22,20,24,21),fill='#d6b8e5')
    elif i==4:
        d.rectangle((6,12,10,23),fill='#827297',outline=o);d.rectangle((24,12,28,23),fill='#827297',outline=o)
        d.polygon([(10,9),(15,5),(24,8),(25,25),(9,25)],fill='#9f89b5',outline=o)
        d.rectangle((11,25,15,29),fill='#6a617f',outline=o);d.rectangle((21,25,25,29),fill='#6a617f',outline=o)
        d.polygon([(11,9),(13,2),(17,6),(20,1),(22,10)],fill='#cca4ef',outline=o)
        d.rectangle((13,13,15,15),fill='#a5ecd1');d.rectangle((21,13,23,15),fill='#a5ecd1')
        d.polygon([(16,19),(19,16),(22,20),(18,24)],fill='#d6b1f6')
    else:
        d.polygon([(10,15),(2,10),(1,18),(8,23)],fill='#82bfc1',outline=o)
        d.polygon([(23,15),(30,10),(31,19),(25,24)],fill='#82bfc1',outline=o)
        d.ellipse((8,7,26,27),fill='#e8d7ac',outline=o)
        d.polygon([(9,10),(8,4),(15,8),(23,4),(25,11)],fill='#f7eacb',outline=o)
        d.ellipse((11,11,17,18),fill=cream);d.ellipse((19,11,25,18),fill=cream)
        d.rectangle((14,13,15,16),fill=eye);d.rectangle((21,13,22,16),fill=eye)
        d.polygon([(17,17),(20,17),(18,20)],fill='#c78959');d.rectangle((13,27,15,29),fill='#c78959');d.rectangle((21,27,23,29),fill='#c78959')
    # Four frames retain consistent silhouettes; gentle bob/walk animation.
    if frame==3:
        for x,y in [(1,5),(28,3),(30,27)]:d.line((x-1,y,x+1,y),fill='#ffe9a9');d.line((x,y-1,x,y+1),fill='#ffe9a9')
    shifted=Image.new('RGBA',(32,32));shifted.paste(im,(0,-1 if frame==1 else 0));return shifted

for frame in range(4):
    for i in range(6):sheet.paste(creature(i,frame),(i*32,frame*32))
sheet.save(OUT/'creatures.png')

# Seamless-ish ground tiles. Seeded for deterministic regeneration.
tiles=Image.new('RGBA',(16*8,16));random.seed(11999)
colors=[('#385e52','#4a7962'),('#76634d','#9b805b'),('#35687c','#5596a3'),('#656078','#8e809e'),('#b79973','#d4b789'),('#24384a','#375466'),('#5e527f','#8d76aa'),('#2b453e','#477059')]
for i,(base,accent) in enumerate(colors):
    tile=Image.new('RGBA',(16,16),base);d=ImageDraw.Draw(tile)
    for n in range(12):
        x,y=random.randrange(15),random.randrange(15);d.line((x,y,x+1,y),fill=accent)
    tiles.paste(tile,(i*16,0))
tiles.save(OUT/'terrain.png')

# Trees, stones and small structures: their own original transparent atlas.
props=Image.new('RGBA',(32*6,48));d=ImageDraw.Draw(props)
for i in range(3):
    x=i*32; trunk='#6f5a51'; foliage=['#568967','#5b87a1','#8a74ad'][i]
    d.rectangle((x+14,24,x+18,43),fill=trunk)
    d.polygon([(x+16,2),(x+3,17),(x+7,19),(x+1,29),(x+30,29),(x+25,19),(x+28,17)],fill=PAL['outline'])
    d.polygon([(x+16,4),(x+5,17),(x+10,18),(x+4,27),(x+27,27),(x+22,18),(x+25,17)],fill=foliage)
    d.line((x+10,17,x+19,17),fill='#96c6a6')
x=96;d.polygon([(x+4,38),(x+7,27),(x+18,24),(x+28,31),(x+29,40)],fill='#8d8299',outline=PAL['outline']);d.line((x+8,29,x+17,27),fill='#baadc4')
x=128;d.rectangle((x+4,19,x+28,35),fill='#916d50',outline=PAL['outline']);d.rectangle((x+7,14,x+26,21),fill='#cfb08a',outline=PAL['outline']);d.rectangle((x+6,18,x+26,22),fill='#70af9b');d.ellipse((x+6,32,x+13,39),fill=PAL['outline']);d.ellipse((x+22,32,x+29,39),fill=PAL['outline'])
x=160;d.rectangle((x+13,13,x+16,42),fill='#785d50');d.rectangle((x+5,11,x+26,22),fill='#cda677',outline=PAL['outline']);d.line((x+9,16,x+22,16),fill='#f0d3a0')
props.save(OUT/'props.png')
print('Original creature atlas (6 x 4 frames), 8 terrains and 6 props generated.')
