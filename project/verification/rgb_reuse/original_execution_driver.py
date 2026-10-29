from pathlib import Path
import re,subprocess,sys,os,concurrent.futures,json,time
root=Path(__file__).resolve().parent.parent
v=root/'verification';run=v/'sim_work';run.mkdir(exist_ok=True)
import shutil,argparse
parser=argparse.ArgumentParser(description='Run integrated ISP/RGB RTL regressions (Icarus Verilog).')
parser.add_argument('--iverilog-bin',type=Path,help='Directory containing iverilog and vvp')
parser.add_argument('--jobs',type=int,default=3)
parser.add_argument('tests',nargs='*')
args=parser.parse_args()
bin=args.iverilog_bin.resolve() if args.iverilog_bin else Path(shutil.which('iverilog') or 'iverilog').resolve().parent
exe='.exe' if os.name=='nt' else ''
if not (bin/('iverilog'+exe)).exists() or not (bin/('vvp'+exe)).exists():
 parser.error('Install Icarus Verilog and add it to PATH, or use --iverilog-bin.')

sources=[]
project=root/'td_project/wb_ui_dsi.al'
for rel in re.findall(r'<File Path="([^"]+\.v)"',project.read_text(encoding='utf8')):
 p=(project.parent/rel).resolve()
 if '.enc.' in p.name or 'ph1p35_ddr' in str(p) or 'mipi_dphy' in str(p) or 'ip_source' in str(p) or 'blk_mem_gen_' in str(p):continue
 sources.append(p)
vendor=root/'user_source/hdl_source/isp/demosaic_4x_2_0/demosaic.v'
shim=run/'demosaic_comments_only.v';shim.write_bytes(re.sub(rb'/\*//(input|output)(\r?\n)',rb'//\1\2',vendor.read_bytes()))
sources=[shim if p==vendor else p for p in sources]
env=os.environ.copy();tmp=run/'tmp';tmp.mkdir(exist_ok=True);env['TEMP']=env['TMP']=str(tmp)
tests=args.tests or ['ui_control_tb','wb_unit_tb','awb_guard_tb','shift_ui_tb','display_filter_tb','alpha_ui_tb','integrated_hud_tb','pipeline_independence_tb','tint_product_tb','gain_product_tb','classifier_bounds_tb','ui_gain_math_tb','component_tb','moment_tb','tracking_tb','histogram_ui_tb','osd_tb']
def check(test):
 group='rgb' if test in ['component_tb','color_gate_tb','color_video_tb','red_equivalence_tb','moment_tb','tracking_tb','mask_tb','red_video_tb','color_noise_tb','color_equivalence_tb','color_presence_tb','display_contract_tb','coordinates_tb','metrics_tb','effects_ui_tb'] else 'isp'
 test_sources=list((v/group).glob('*.sv')) if (v/group).exists() else []
 test_sources+=list(v.glob('*.sv'))
 if group=='rgb':test_sources+=list((v/'rgb/red_reference').glob('*.v'))
 obj=run/(test+'.vvp');start=time.monotonic()
 with (run/(test+'_elab.log')).open('w') as f:
  p=subprocess.run([str(bin/('iverilog'+exe)),'-g2012','-s',test,'-o',str(obj),*map(str,sources+test_sources)],stdout=f,stderr=subprocess.STDOUT,cwd=run,env=env)
 if p.returncode:return test,False,'compile '+str(p.returncode)
 with (run/(test+'_run.log')).open('w') as f:
  p=subprocess.run([str(bin/('vvp'+exe)),str(obj)],stdout=f,stderr=subprocess.STDOUT,cwd=run,env=env)
 text=(run/(test+'_run.log')).read_text(errors='replace');passes=[l for l in text.splitlines() if l.startswith('PASS')]
 ok=p.returncode==0 and len(passes)==1 and not re.search(r'FATAL:|^ERROR:',text,re.M)
 return test,ok,(passes[0] if ok else text[-1600:])+f' [{time.monotonic()-start:.1f}s]'
results=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
 for result in pool.map(check,tests):
  results.append(result);print(result,flush=True)
(run/'latest_results.json').write_text(json.dumps(results,indent=2),encoding='utf8')
sys.exit(0 if all(r[1] for r in results) else 1)
