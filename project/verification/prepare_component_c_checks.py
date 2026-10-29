from pathlib import Path
root=Path(__file__).resolve().parent.parent
parent=root.parent/'opt27/verification'
for name in ['component_prefetch_opt27_tb.sv','component_prefetch_native_opt27_tb.sv','component_prefetch_fault_opt27_tb.sv']:
 text=(parent/name).read_text(encoding='utf8')
 assert text.count('`include "../prototypes/prefetch_color_components_opt27.sv"\n')==1
 text=text.replace('`include "../prototypes/prefetch_color_components_opt27.sv"\n','')
 assert text.count('prefetch_color_components_opt27 ')==1
 text=text.replace('prefetch_color_components_opt27 ','color_components ',1)
 (root/'verification'/name).write_text(text,encoding='utf8')
print('Prepared independent C active component checks; no prototype module dependency')
