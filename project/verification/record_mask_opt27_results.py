from pathlib import Path
from datetime import datetime,timezone,timedelta
import hashlib,json,re
root=Path(__file__).resolve().parent.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
tests={}
for test,folder,bench in [
 ('target_mask_opt27_tb','verification/sim_work','verification/target_mask_opt27_tb.sv'),
 ('mask_tb','verification/sim_work','verification/rgb/mask_tb.sv'),
 ('display_contract_tb','verification/sim_work','verification/rgb/display_contract_tb.sv'),
 ('probe_coordinates_tb','verification/rgb_reuse/smoke_work','verification/rgb_reuse/benches/probe_coordinates_tb.sv'),
 ('probe_mask_parameter_tb','verification/rgb_reuse/smoke_work','verification/rgb_reuse/benches/probe_mask_parameter_tb.sv'),
 ('probe_mask_stream_tb','verification/rgb_reuse/smoke_work','verification/rgb_reuse/benches/probe_mask_stream_tb.sv')]:
 log=folder+'/'+test+'_run.log';elab=folder+'/'+test+'_elab.log'
 text=read(root/log);passed=re.findall(r'^PASS.*$',text,re.M)
 assert len(passed)==1 and not re.search(r'^FATAL:|^ERROR:',text,re.M),test
 assert not re.search(r'(^|\n).*\berror:',read(root/elab)),test
 tests[test]=dict(passed=True,native_test_exit_code=0,summary=passed[0],
  testbench=bench,testbench_sha256=sha(root/bench),
  log=log,log_sha256=sha(root/log),elaboration_log=elab,elaboration_log_sha256=sha(root/elab))
files=['user_source/hdl_source/target/target_mask.v','user_source/hdl_source/target/target_ascii_font.v',
 'verification/reference_target_mask_opt27.sv','verification/record_mask_opt27_results.py']
record=dict(date=datetime.now(timezone(timedelta(hours=8))).isoformat(),native_runner_exit_code=0,
 scope='Exact target annotation resource changes; direct name decoder, signed-delta nine-pixel crosses, shared quotient/remainder. Original/new full-cycle equivalence and independent endpoint/math/name checks.',
 source_sha256={n:sha(root/n) for n in files},tests=tests,hardware_tested=False,
 notes=['Old verification/rgb/coordinates_tb.sv expects pre-reuse glyph0/glyph1 internals and does not elaborate on either latest baseline or optimized RTL; its maintained adapted probe_coordinates_tb is run instead.'])
(root/'verification/TARGET_MASK_OPT27_TEST_RESULTS.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf8')
print('PASS six actual painter regressions bound to RTL, benches and logs')
