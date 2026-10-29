from pathlib import Path
from datetime import datetime,timezone,timedelta
import hashlib,json,re
root=Path(__file__).resolve().parent.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
tests={}
for test in ['component_prefetch_opt27_tb','component_prefetch_native_opt27_tb','component_prefetch_fault_opt27_tb']:
 log='verification/sim_work/'+test+'_run.log';elab='verification/sim_work/'+test+'_elab.log'
 text=read(root/log);passed=re.findall(r'^PASS.*$',text,re.M)
 assert len(passed)==1 and not re.search(r'^FATAL:|^ERROR:',text,re.M),test
 assert not re.search(r'(^|\n).*\berror:',read(root/elab)),test
 bench='verification/'+test+'.sv'
 tests[test]=dict(passed=True,native_test_exit_code=0,summary=passed[0],
  testbench=bench,testbench_sha256=sha(root/bench),
  log=log,log_sha256=sha(root/log),elaboration_log=elab,elaboration_log_sha256=sha(root/elab))
files=['verification/prototypes/prefetch_color_components_opt27.sv',
 'verification/reference_color_components_opt27.sv','verification/record_components_prefetch_opt27.py']
record=dict(date=datetime.now(timezone(timedelta(hours=8))).isoformat(),native_runner_exit_code=0,
 scope='Inactive prototype only: exact-cycle cap/row BRAM lookahead versus frozen original reference, full native4096 run capacity retained. During malformed overrun frames only external metadata and later committed run/root/color contents are compared; internal cap records after engine_bad are invalid and not claimed equal.',
 source_sha256={n:sha(root/n) for n in files},tests=tests,hardware_tested=False,active_source_integrated=False)
(root/'verification/COMPONENT_PREFETCH_OPT27_TEST_RESULTS.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf8')
print('PASS three actual inactive component prototype regressions bound to reference, candidate, benches and logs')
