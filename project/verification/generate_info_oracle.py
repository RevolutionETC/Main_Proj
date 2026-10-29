from pathlib import Path
import re,json,hashlib
root=Path(__file__).resolve().parent.parent
ui=root/'user_source/hdl_source/ui'
v=root/'verification'
text=(ui/'wb_ui_overlay.v').read_text(encoding='utf8')
digits=[]
for n in range(10):
    m=re.search(r"4'd"+str(n)+r":digit_glyph=8'd(\d+)",text)
    assert m,n
    digits.append(int(m[1]))
minus=re.search(r"CHAR_MINUS=8'd(\d+)",text)
assert minus,'New information page must include a minus glyph for invalid age'
digits.append(int(minus[1]))
(v/'info_digit_indices.hex').write_text(''.join(f'{n:02x}\n' for n in digits),encoding='ascii')
font=(ui/'wb_ui_font.hex').read_text().splitlines()
assert len(font)<=8192
(v/'info_oracle_font.hex').write_text('\n'.join(font+['000000']*(8192-len(font)))+'\n',encoding='ascii')
ascii_source=(root/'user_source/hdl_source/target/target_ascii_font.v').read_text()
glyphs=[0]*(256*7)
for c,bits in re.findall(r'"(.)":glyph=35\'b([01_]+)',ascii_source):
    raw=bits.replace('_','');assert len(raw)==35
    for row in range(7):glyphs[ord(c)*7+row]=int(raw[row*5:row*5+5],2)
(v/'info_ascii_rows.hex').write_text(''.join(f'{n:02x}\n' for n in glyphs),encoding='ascii')
print('PASS information-page test font assets: independent numeric/ASCII formatting oracle')
