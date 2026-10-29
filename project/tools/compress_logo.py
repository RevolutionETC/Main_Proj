"""Losslessly crop transparent borders and palette-index the original logo."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parent.parent
p=root/'user_source/hdl_source/osd/anlogic_logo.hex'
raw=[int(x,16) for x in p.read_text().split()];assert len(raw)==160*160
palette=sorted(set(raw));assert len(palette)==580
ids={c:i for i,c in enumerate(palette)}
assert palette[0]==0
cropped=[ids[raw[y*160+x]] for y in range(34,128) for x in range(7,153)]
Path(str(p)+'.index').write_text(''.join(f'{i:03x}\n' for i in cropped),encoding='ascii')
Path(str(p)+'.index.dat').write_text(''.join(f'{i:010b}\n' for i in cropped),encoding='ascii')
Path(str(p)+'.palette').write_text(''.join(f'{c:07x}\n' for c in palette),encoding='ascii')
decoded=[palette[cropped[(y-34)*146+x-7]] if 7<=x<153 and 34<=y<128 else 0 for y in range(160) for x in range(160)]
assert decoded==raw
print('PASS lossless logo: 25600 identical RGBA pixels; 640000 -> 151740 stored bits (76.29% fewer)')
