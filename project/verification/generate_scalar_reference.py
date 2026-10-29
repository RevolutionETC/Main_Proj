"""Independent integer/picture reference for the scalar enhancement and retro paths."""
from pathlib import Path
import math
out=Path(__file__).resolve().parent/'fixtures';out.mkdir(exist_ok=True)
W,H=24,16
def image(x,y):return ((x*17+y*5+3)%256,(x*7+y*23+19)%256,(x*31+y*11+47)%256)
def yc(c):
 r,g,b=c;co=r-b;t=b+co//2;cg=g-t;return t+cg//2,co,cg
def pixel(c):return (int(c[0])<<16)|(int(c[1])<<8)|int(c[2])
def clamp(x):return min(255,max(0,x))
def advance(r):return ((r<<1)&65535)|(((r>>15)^(r>>13)^(r>>12)^(r>>10))&1)
enhanced=[];retro=[];noise=0x1ace
for y in range(H):
 for x in range(W):
  a=[yc(image(min(W-1,max(0,x+dx)),min(H-1,max(0,y+dy)))) for dy in [-1,0,1] for dx in [-1,0,1]]
  gx=a[2][0]+2*a[5][0]+a[8][0]-a[0][0]-2*a[3][0]-a[6][0]
  gy=a[6][0]+2*a[7][0]+a[8][0]-a[0][0]-2*a[1][0]-a[2][0];mag=abs(gx)+abs(gy)
  blur=[(sum(w*n[k] for w,n in zip([1,2,1,2,4,2,1,2,1],a))+8)//16 for k in range(3)]
  yy,co,cg=[c if mag>=384 else (c+b+1)//2 if mag>=192 else b for c,b in zip(a[4],blur)]
  shadow=yy<32
  yy=yy if shadow else min(255,((yy+4)//8)*8)
  co=co if shadow else ((co+2)//4)*4;cg=cg if shadow else ((cg+2)//4)*4
  t=yy-cg//2;b=t-co//2;g=cg+t;r=b+co;c=[clamp(r),clamp(g),clamp(b)]
  m=max(c);gain=640 if m==0 else min(640,round(256*(255/m)**.2))
  c=[min(255,(v*gain+128)//256) for v in c];m=max(c)
  c=[max(0,v-(m-v+2)//4) for v in c]
  c=[v*7//8 if mag>=256 else v*15//16 if mag>=128 else v*31//32 if mag>=64 else v for v in c]
  enhanced.append(pixel(c))
  r,g,b=image(x,y);luma=(77*r+150*g+29*b+128)//256;tone=8+239*(luma/255)**.94
  c=[clamp(round(a*tone+b)) for a,b in [(1.04,5),(.94,1),(.76,-2)]]
  qx=abs(x-W//2)//32;qy=abs(y-H//2)//16
  gain=256-min(60,(qx*qx+8)//16)-min(60,(qy*qy+8)//16)//2
  grain=[-1,0,0,1][(noise>>6)&3];noise=advance(noise)
  retro.append(pixel([clamp((v*gain+128)//256+grain) for v in c]))
for name,values in [('scalar_enhance',enhanced),('scalar_retro',retro)]:
 (out/(name+'.hex')).write_text(''.join(f'{v:06x}\n' for v in values),encoding='ascii')
print('Generated independent integer references: shared-window enhancement and retro, 384 pixels each')
