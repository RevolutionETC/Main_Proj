from pathlib import Path
from datetime import datetime,timezone,timedelta
import hashlib,json,re

root=Path(__file__).resolve().parent.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
tests=['info_panel_tb','info_bars_equivalence_tb','info_preview_tb','ui_decimal_info_tb',
       'ui_frame_config_tb','ui_gain_math_tb','ui_decimal_tb','ui_bars_config_tb','integrated_hud_tb','alpha_ui_tb']
groups={'info_panel_tb':'pixel_batch',
        'info_bars_equivalence_tb':'preview_decimal_bar_batch','info_preview_tb':'preview_decimal_bar_batch',
        'ui_decimal_info_tb':'preview_decimal_bar_batch'}
exits=json.loads((root/'verification/INFO_OVERLAY_BATCH_EXITS.json').read_text())
assert set(exits)=={'pixel_batch','preview_decimal_bar_batch','legacy_ui_batch'}
assert all(x['actual_exit_code']==0 for x in exits.values())
tb_paths={'ui_frame_config_tb':'verification/isp/ui_frame_config_tb.sv',
          'ui_decimal_tb':'verification/isp/isp_ui_tb.sv'}
records={}
for test in tests:
    run=f'verification/sim_work/{test}_run.log';elab=f'verification/sim_work/{test}_elab.log'
    text=(root/run).read_text(errors='replace');passes=re.findall(r'^PASS.*$',text,re.M)
    assert len(passes)==1 and not re.search(r'^FATAL:|^ERROR:',text,re.M),test
    tb=tb_paths.get(test,f'verification/{test}.sv')
    records[test]=dict(actual_exit=exits[groups.get(test,'legacy_ui_batch')]['actual_exit_code'],
        passed=True,summary=passes[0],run_log=run,run_log_sha256=sha(root/run),
        elaboration_log=elab,elaboration_log_sha256=sha(root/elab),
        testbench=tb,testbench_sha256=sha(root/tb))
sources=['tools/wb_ui_overlay.template.v','tools/generate_wb_ui.py',
         'user_source/hdl_source/ui/wb_ui_overlay.v','user_source/hdl_source/ui/wb_ui_font.v',
         'user_source/hdl_source/ui/wb_ui_font.hex','user_source/hdl_source/ui/wb_ui_text_rom.v',
         'user_source/hdl_source/ui/wb_ui_text.hex']
assets=['verification/info_digit_indices.hex','verification/info_oracle_font.hex','verification/info_ascii_rows.hex',
        'verification/reference_ui_overlay.sv','verification/reference_ui_assets/wb_ui_font.hex',
        'verification/reference_ui_assets/wb_ui_text.hex','verification/generate_info_oracle.py']
previews={}
for name in ['info_swipe_menu.png','info_swipe_information.png','info_swipe_information_hidden.png']:
    rel='previews/'+name
    previews[rel]=dict(sha256=sha(root/rel),source='Actual info_preview_tb RTL output; test pattern, not board camera capture')
data=dict(date=datetime.now(timezone(timedelta(hours=8))).isoformat(),actual_exit=0,
    hardware_tested=False,scope='Combined information-page independent decimal/ASCII output oracle, exact old-bar comparison except intentional gesture-hint text, shared serial converter original-cycle preservation, frame atomicity and current RTL previews',
    tests=records,source_files_sha256={name:sha(root/name) for name in sources},
    oracle_assets_sha256={name:sha(root/name) for name in assets},batch_actual_exits=exits,
    bar_reference='Previously delivered 20261026_UI_FIX exact overlay/font/text assets; only x16..207/y574..597 gesture hint intentionally excluded in page0',
    previews=previews,historical_logs_not_represented_as_current_runs=True)
(root/'verification/INFO_OVERLAY_TEST_RESULTS.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
print('PASS recorded ten actual information-overlay regressions and three RTL previews')
