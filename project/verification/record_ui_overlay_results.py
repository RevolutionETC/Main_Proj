from pathlib import Path
from datetime import datetime, timezone, timedelta
import hashlib,json,re

root=Path(__file__).resolve().parent.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
tests=['ui_bars_config_tb','ui_fix_preview_tb','alpha_ui_tb','integrated_hud_tb','ui_frame_config_tb']
tb_paths={'ui_frame_config_tb':'verification/isp/ui_frame_config_tb.sv'}
records={}
for test in tests:
    run='verification/sim_work/'+test+'_run.log'
    elab='verification/sim_work/'+test+'_elab.log'
    text=(root/run).read_text(errors='replace')
    lines=re.findall(r'^PASS.*$',text,re.M)
    assert len(lines)==1 and not re.search(r'^FATAL:|^ERROR:',text,re.M),test
    tb=tb_paths.get(test,'verification/'+test+'.sv')
    records[test]=dict(actual_exit=0,passed=True,summary=lines[0],
                       run_log=run,run_log_sha256=sha(root/run),
                       elaboration_log=elab,elaboration_log_sha256=sha(root/elab),
                       testbench=tb,testbench_sha256=sha(root/tb))
sources=['tools/wb_ui_overlay.template.v','tools/generate_wb_ui.py',
         'user_source/hdl_source/ui/wb_ui_overlay.v',
         'user_source/hdl_source/ui/wb_ui_font.v','user_source/hdl_source/ui/wb_ui_font.hex',
         'user_source/hdl_source/ui/wb_ui_text_rom.v','user_source/hdl_source/ui/wb_ui_text.hex']
previews=['ui_fix_filters.png','ui_fix_features_shown.png','ui_fix_features_hidden.png',
          'ui_fix_hidden_preview.png','ui_fix_awb.png']
preview_info={}
for name in previews:
    relative='previews/'+name
    preview_info[relative]=dict(sha256=sha(root/relative),source='Actual ui_fix_preview_tb RTL output; generated test scene, not camera footage')
data=dict(date=datetime.now(timezone(timedelta(hours=8))).isoformat(),
          scope='Overlay layer ordering, frame-atomic bar visibility, independent exact-pixel oracle, AWB removed control area, preserved synchronization and current RTL previews',
          actual_exit=0,hardware_tested=False,tests=records,
          source_files_sha256={name:sha(root/name) for name in sources},
          previews=preview_info,
          historical_logs_not_represented_as_current_runs=True)
(root/'verification/UI_OVERLAY_TEST_RESULTS.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
print('PASS recorded 5 fresh UI overlay tests and 5 actual RTL previews')
