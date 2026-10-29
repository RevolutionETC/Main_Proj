from pathlib import Path
root=Path(__file__).resolve().parent.parent
baseline=root.parent/'integration_20261026_info_swipe/ISP_RGB_SC500_INTEGRATED/user_source/hdl_source/target'
old=(baseline/'color_components.v').read_text(encoding='utf8')
assert old.count('module color_components #(')==1
(root/'verification/reference_color_components_opt27.sv').write_text(old.replace('module color_components #(','module reference_color_components_opt27 #(',1),encoding='utf8')
for filename in ['component_prefetch_opt27_tb.sv','component_prefetch_native_opt27_tb.sv']:
 path=root/'verification'/filename;text=path.read_text(encoding='utf8')
 assert text.count(' color_components ')==1
 path.write_text(text.replace(' color_components ',' reference_color_components_opt27 ',1),encoding='utf8')
active=(root/'user_source/hdl_source/target/target_mask.v').read_text(encoding='utf8')
original=(baseline/'target_mask.v').read_text(encoding='utf8')
start=active.index(' // Decode the fixed names directly')
end=active.index(' wire [4:0] computed_len=',start)
namechar=active[start:end]
anchor=' wire [4:0] computed_len='
assert original.count(anchor)==1
original=original.replace(anchor,namechar+anchor,1)
before='''  integer n,p;reg [71:0] word;begin
   n=name_length(kind);word=kind==1?"CIRCLE":kind==2?"RECTANGLE":"TRIANGLE";p=pos-n-2;
   if(pos<n)label_char=word>>((n-1-pos)*8);'''
after='''  integer n,p;begin
   n=name_length(kind);p=pos-n-2;
   if(pos<n)label_char=name_char(pos,kind);'''
assert original.count(before)==1
original=original.replace(before,after)
(root/'verification/prototypes/target_mask_namecase_candidate.v').write_text(original,encoding='utf8')
print('Prepared independent original component reference and inactive painter name-case-only candidate')
