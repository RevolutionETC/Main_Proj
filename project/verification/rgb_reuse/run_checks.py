from pathlib import Path
import argparse,concurrent.futures,datetime,hashlib,json,os,re,shutil,subprocess,sys,time

bundle=Path(__file__).resolve().parent
root=bundle.parents[1]
parser=argparse.ArgumentParser(description='Verify exact RGB resource reuse against stored original RTL.')
parser.add_argument('--iverilog-bin',type=Path,required=True)
parser.add_argument('--jobs',type=int,default=3)
parser.add_argument('tests',nargs='*')
args=parser.parse_args()
default=['probe_scale_tb','probe_tracking_tb','probe_mask_tb','probe_coordinates_tb',
 'probe_mask_parameter_tb','probe_mask_stream_tb','tracking_tb','mask_tb','red_equivalence_tb','color_equivalence_tb']
tests=args.tests or default
assert len(tests)==len(set(tests)) and all(t in default for t in tests)
exe='.exe' if os.name=='nt' else ''
bin=args.iverilog_bin.resolve()
assert all((bin/(n+exe)).is_file() for n in ['iverilog','vvp'])
work=bundle/'smoke_work';work.mkdir(exist_ok=True)
env=os.environ.copy();tmp=work/'tmp';tmp.mkdir(exist_ok=True);env['TMP']=env['TEMP']=str(tmp)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
target_names=['hdl_source/target/target_mask.v','hdl_source/target/target_shape_stabilizer.v']
target_hashes={n:sha(root/'user_source'/n) for n in target_names}
sources=[]
project=root/'td_project/wb_ui_dsi.al'
for rel in re.findall(r'<File Path="([^"]+\.v)"',project.read_text(encoding='utf8')):
 p=(project.parent/rel).resolve()
 if '.enc.' in p.name or 'ph1p35_ddr' in str(p) or 'mipi_dphy' in str(p) or 'ip_source' in str(p) or 'blk_mem_gen_' in str(p):continue
 sources.append(p)
vendor=root/'user_source/hdl_source/isp/demosaic_4x_2_0/demosaic.v'
shim=work/'demosaic_comments_only.v';shim.write_bytes(re.sub(rb'/\*//(input|output)(\r?\n)',rb'//\1\2',vendor.read_bytes()))
sources=[shim if p==vendor else p for p in sources]
test_sources=sorted((bundle/'benches').rglob('*.sv'))+sorted((bundle/'reference').rglob('*.sv'))+sorted((bundle/'reference').rglob('*.v'))
def check(test):
 started=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat()
 clock=time.monotonic();elab=work/(test+'_elab.log');log=work/(test+'_run.log');obj=work/(test+'.vvp')
 with elab.open('w') as out:
  p=subprocess.run([str(bin/('iverilog'+exe)),'-g2012','-s',test,'-o',str(obj),*map(str,sources+test_sources)],cwd=work,env=env,stdout=out,stderr=subprocess.STDOUT)
 elab_exit=p.returncode;sim_exit=None;text=''
 if elab_exit==0:
  with log.open('w') as out:p=subprocess.run([str(bin/('vvp'+exe)),str(obj)],cwd=work,env=env,stdout=out,stderr=subprocess.STDOUT)
  sim_exit=p.returncode;text=log.read_text(errors='replace')
 passes=[line for line in text.splitlines() if line.startswith('PASS')]
 ok=elab_exit==0 and sim_exit==0 and len(passes)==1 and not re.search(r'FATAL:|^ERROR:',text,re.M)
 record=dict(test=test,passed=ok,elaboration_exit=elab_exit,simulation_exit=sim_exit,
  started=started,finished=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
  seconds=round(time.monotonic()-clock,3),source_hashes=target_hashes,
  testbench='benches/'+test+'.sv',testbench_sha256=sha(bundle/'benches'/(test+'.sv')),
  elaboration_log=str(elab.relative_to(bundle)),elaboration_log_sha256=sha(elab),
  log=str(log.relative_to(bundle)),log_sha256=sha(log) if log.exists() else None,
  summary=passes[0] if ok else text[-1200:])
 print((test,ok,record['summary']),flush=True)
 return record
with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:records=list(pool.map(check,tests))
assert target_hashes=={n:sha(root/'user_source'/n) for n in target_names},'Source changed while tests ran'
report=dict(schema=1,scope='Known states after reset; uninitialized or X bank addressing is not claimed four-state equivalent.',
 source_hashes=target_hashes,runner='run_checks.py',runner_sha256=sha(Path(__file__)),
 records=records,all_passed=all(r['passed'] for r in records),physical_timing_qualified=False)
(bundle/'SMOKE_RESULTS.json').write_text(json.dumps(report,indent=2),encoding='utf8')
sys.exit(0 if report['all_passed'] else 1)
