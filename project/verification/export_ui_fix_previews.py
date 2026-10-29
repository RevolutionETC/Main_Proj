from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parent.parent
files={
 'ui_fix_0_page_7_hide_0.ppm':'ui_fix_filters.png',
 'ui_fix_1_page_8_hide_0.ppm':'ui_fix_features_shown.png',
 'ui_fix_2_page_8_hide_1.ppm':'ui_fix_features_hidden.png',
 'ui_fix_3_page_0_hide_1.ppm':'ui_fix_hidden_preview.png',
 'ui_fix_4_page_2_hide_0.ppm':'ui_fix_awb.png',
}
for source,target in files.items():
    with Image.open(root/'verification/sim_work'/source) as image:
        assert image.size==(1024,600)
        image.save(root/'previews'/target)
print('PASS exported five actual RTL UI frames; test scene, not camera footage')
