from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
r=Path(__file__).resolve().parent
labels=['自动白平衡','环境预设','手动白平衡','暖色灯光 3000K','日光 5500K','阴天 6500K','阴影 7500K','原图','边缘','像素画','复古','视觉增强','黑白','动漫','负片','选择光照环境']
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
rows=[]
for label in labels:
 for c in label.ljust(16):
  im=Image.new('L',(24,24));d=ImageDraw.Draw(im);box=d.textbbox((0,0),c,font=font)
  d.text(((24-(box[2]-box[0]))//2-box[0],(24-(box[3]-box[1]))//2-box[1]),c,font=font,fill=255)
  for y in range(32):
   bits=0
   for x in range(24):bits=(bits<<1)|int(y<24 and im.getpixel((x,y))>=100)
   rows.append(f'{bits:06x}')
(r/'restored_ui_literal_rows.hex').write_text('\n'.join(rows)+'\n',encoding='ascii')
print('Generated independent literal Chinese UI oracle:16 labels, no production font/text-ROM inputs')
