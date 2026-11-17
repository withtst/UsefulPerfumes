"""Produce in-bottle liquid-level textures from the current 32px reference icons."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]; TEX=ROOT/'42.21/media/textures'; LEVELS=TEX/'UPLiquidLevels';LEVELS.mkdir(exist_ok=True)
OUT=ROOT/'tools/output';OUT.mkdir(parents=True,exist_ok=True)
# x0, y0, x1, y1 refer to the bottle interior on the 32x32 reference icon.
BOTTLES=[
 ('Blueberry','First Love Blueberry',(13,10,17,28),(14,14,16,23),(213,169,76)),
 ('Cheap','Cheap Knockoff',(11,10,19,28),(12,12,18,26),(191,71,98)),
 ('Elegant','Elegant Miss',(8,14,22,28),(11,17,19,21),(222,84,145)),
 ('Herbal','Herbal Blend',(8,10,23,28),(11,16,20,23),(214,148,45)),
 ('ColdCotton','Cold Cotton',(8,10,23,28),None,(112,153,103)),
 ('Slumber','Slumber Floral',(13,8,18,28),(14,14,17,18),(160,104,196)),
]
try:
 font=ImageFont.truetype('arial.ttf',15)
except OSError:
 font=ImageFont.load_default()
preview=Image.new('RGB',(1000,680),(48,50,54));pd=ImageDraw.Draw(preview)
for idx,(key,name,box,label,color) in enumerate(BOTTLES):
 original=Image.open(TEX/f'Item_UP_{key}Perfume.png').convert('RGBA');x0,y0,x1,y1=box
 empty=original.copy(); region=[]
 for y in range(y0,y1+1):
  for x in range(x0,x1+1):
   r,g,b,a=original.getpixel((x,y));inside=a>=240
   in_label=label and label[0]<=x<=label[2] and label[1]<=y<=label[3]
   if not inside or (in_label and key != "Cheap"):continue
   # Desaturate the interior to give the unfilled part a glass appearance.
   lum=round(.30*r+.59*g+.11*b);glass=tuple(round(.35*v+.65*lum) for v in (188,198,203))
   if in_label: glass=tuple(round(.50*v+.50*g) for v,g in zip((r,g,b),glass))
   empty.putpixel((x,y),glass+(a,));region.append((x,y,bool(in_label)))
 # Native fallback mask is confined to the bottle; item-list rendering uses frames below.
 mask=Image.new('RGBA',(32,32))
 for x,y,islabel in region:mask.putpixel((x,y),(255,255,255,105))
 mask.save(TEX/f'Item_UP_{key}Perfume_Mask.png')
 cells={}
 for level in range(21):
  im=empty.copy(); count=round((y1-y0+1)*level/20);cut=y1-count+1
  for x,y,islabel in region:
   if y>=cut and count>0:
    r,g,b,a=empty.getpixel((x,y)); strength=.38 if islabel else .76; filled=tuple(round((1-strength)*v+strength*c) for v,c in zip((r,g,b),color))
    if y==cut:filled=tuple(min(255,round(v*.85+38)) for v in filled)
    im.putpixel((x,y),filled+(a,))
  im.save(LEVELS/f'{key}_{level:02d}.png')
  if level in (0,5,10,15,20):cells[level]=im
 px=20+(idx%2)*490;py=14+(idx//2)*220;pd.text((px,py),name,font=font,fill='white')
 for j,level in enumerate((0,5,10,15,20)):
  im=cells[level];big=im.resize((80,80),Image.Resampling.NEAREST);x=px+j*92;y=py+30;preview.paste(big,(x,y),big);pd.text((x,y+86),str(level*5)+'%',font=font,fill='#cbd0d5')
  preview.paste(im,(x+24,y+118),im)
preview.save(OUT/'liquid_levels_preview.png')
print('Generated six in-bottle masks and 126 level textures.')

