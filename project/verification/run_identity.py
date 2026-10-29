from pathlib import Path
import os
import subprocess
import sys
import time

verification = Path(__file__).resolve().parent
root = verification.parent
bins = Path(sys.argv[1]).resolve()
phy = root / 'user_source/hdl_source/ph1p35_ddr/ddr2/src/rtl/phy'
sources = [verification / 'vendor_logic_buf_functional.v',
           verification / 'original_fast_init_wrapper.v',
           phy / 'ph1p_ddrphy_fast_init_wrapper.v',
           phy / 'ph1p_ddrphy_fast_init.v',
           verification / 'buffer_identity_tb.sv']
environment = os.environ.copy()
temporary = verification / 'tmp'
temporary.mkdir(exist_ok=True)
environment['TMP'] = environment['TEMP'] = str(temporary)
command = [str(bins / 'iverilog.exe'), '-g2012', '-DPH1P_DDRPHY_SIM',
           '-s', 'buffer_identity_tb', '-o', str(verification / 'buffer_identity_tb.vvp')]
with (verification / 'buffer_identity_elab.log').open('w') as output:
    code = subprocess.call(command + [str(p) for p in sources], stdout=output,
                           stderr=subprocess.STDOUT, cwd=str(verification), env=environment)
assert code == 0, (verification / 'buffer_identity_elab.log').read_text(errors='replace')
started = time.time()
with (verification / 'buffer_identity_run.log').open('w') as output:
    code = subprocess.call([str(bins / 'vvp.exe'), str(verification / 'buffer_identity_tb.vvp')],
                           stdout=output, stderr=subprocess.STDOUT,
                           cwd=str(verification), env=environment)
result = (verification / 'buffer_identity_run.log').read_text(errors='replace')
print(result)
print('elapsed: {:.3f}s'.format(time.time() - started))
assert code == 0 and result.startswith('PASS ')
