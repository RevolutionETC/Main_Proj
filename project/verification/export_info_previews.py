from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parent.parent
names=['info_swipe_menu.png','info_swipe_information.png','info_swipe_information_hidden.png']
for n,name in enumerate(names):
    src=root/'verification/sim_work'/f'info_swipe_{n}.ppm'
    with Image.open(src) as im:
        assert im.size==(1024,600)
        im.save(root/'previews'/name)
print('PASS exported three actual RTL information-page previews')
