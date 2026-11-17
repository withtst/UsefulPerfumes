from pathlib import Path
from PIL import Image, ImageChops
import re,hashlib
root=Path(__file__).resolve().parents[1]; tex=root/'42.21/media/textures'; out=root/'tools/output';src=(root/'42.21/media/scripts/item/UP_PerfumeItems.txt').read_text(encoding='utf-8')
keys={'UP_FirstLoveBlueberry':'Blueberry','UP_CheapKnockoff':'Cheap','UP_ElegantMiss':'Elegant','UP_HerbalBlend':'Herbal','UP_ColdCotton':'ColdCotton','UP_SlumberFloral':'Slumber'}
lines=[];bad=[]
def chk(ok,name,info=''):
 lines.append(('PASS ' if ok else 'FAIL ')+name+' '+str(info))
 if not ok:bad.append(name)
for item,key in keys.items():
 m=re.search(r'item\s+'+item+r'\s*\{(.*?)\n    \}',src,re.S)
 chk(bool(m) and ('IconFluidMask = UP_'+key+'Perfume_Mask') in m.group(1),key+' reference')
 icon=Image.open(tex/f'Item_UP_{key}Perfume.png').convert('RGBA'); mask=Image.open(tex/f'Item_UP_{key}Perfume_Mask.png').convert('RGBA');ia=icon.getchannel('A');ma=mask.getchannel('A')
 chk(ma.getbbox() is not None and all(ma.getpixel((x,y))==0 for y in range(32) for x in range(32) if ia.getpixel((x,y))<240),key+' mask inside bottle')
 chk(all(ma.getpixel((x,y))==0 for x in (28,29,30,31) for y in range(32)),key+' no side gauge')
 levels=[];allframes=[]
 for n in range(21):
  p=tex/'UPLiquidLevels'/f'{key}_{n:02d}.png';im=Image.open(p).convert('RGBA');allframes.append(im)
  if n in (0,5,10,15,20):levels.append(im)
  chk(im.size==(32,32) and im.getchannel('A').tobytes()==ia.tobytes(),f'{key} frame {n:02d} alpha and size')
  chk(all(im.getpixel((x,y))==icon.getpixel((x,y)) for x in (28,29,30,31) for y in range(32)),f'{key} frame {n:02d} no side bar')
 diffs=[sum(1 for a,b in zip(levels[i].convert('RGB').getdata(),levels[i+1].convert('RGB').getdata()) if a!=b) for i in range(4)]
 chk(all(n>=4 for n in diffs),key+' distinct five levels',diffs)
 lines.append('SHA256 '+hashlib.sha256((tex/'UPLiquidLevels'/f'{key}_20.png').read_bytes()).hexdigest()+' '+key+'_20.png')
for n in ['Item_Perfume1_Mask.png','Item_Cologne_Mask.png']:chk(not (tex/n).exists(),n+' no vanilla override')
lines.append(f'BOTTLELEVEL|pass={sum(x.startswith("PASS ") for x in lines)}|fail={len(bad)}');out.mkdir(parents=True,exist_ok=True);(out/'checks.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8');print(lines[-1]);print('\n'.join(bad));raise SystemExit(bool(bad))
