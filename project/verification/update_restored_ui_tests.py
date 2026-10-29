from pathlib import Path
r=Path('res27/verification')
p=r/'isp/ui_test.sv';s=p.read_text()
s=s.replace('if(page==3||(mode!==2\'d0&&mode!==2\'d2))$fatal(1,"Removed preset page/mode became reachable");','if(mode>2)$fatal(1,"Invalid WB mode became reachable");')
s=s.replace('expect_page(1);tap(700,220);expect_page(4);','expect_page(1);tap(700,300);expect_page(4);')
a=s.index('  tap(700,192);expect_page(4)');b=s.index('  tap(700,140);expect_page(2);if(mode!=0||index!=75)',a)
s=s[:a]+'''  // Environment row opens a selector without altering the applied mode/index.
  tap(700,192);expect_page(3);if(mode!=0||index!=75)$fatal(1,"Preset entry changed applied configuration");tap(620,50);
  tap(700,255);expect_page(3);tap(620,50);
  tap(584,220);expect_page(3);tap(620,50);
  tap(999,220);expect_page(3);tap(620,50);
  tap(700,272);expect_page(4);if(mode!=2||index!=75)$fatal(1,"Manual lower edge");tap(620,50);
  tap(999,335);expect_page(4);tap(620,50);
  tap(583,220);tap(1000,220);tap(700,176);tap(700,191);tap(700,256);tap(700,336);expect_page(1);
'''+s[b:]
s=s.replace('tap(620,50);tap(700,220);expect_page(4);','tap(620,50);tap(700,300);expect_page(4);')
s=s.replace('// Every 100 K step must survive AWB/manual round trips with no backup preset state.','// Every 100 K step must survive all four presets and AWB/manual round trips.')
a=s.index('   tap(620,50);tap(700,140);expect_page(2);if(mode!=0||index!=i)')
s=s[:a]+'''   tap(620,50);tap(700,220);expect_page(3);
   tap(700,140);if(mode!=1||index!=5)$fatal(1,"Warm preset step%0d",i);
   tap(700,220);if(mode!=1||index!=30)$fatal(1,"Daylight preset step%0d",i);
   tap(700,300);if(mode!=1||index!=40)$fatal(1,"Cloudy preset step%0d",i);
   tap(700,380);if(mode!=1||index!=50)$fatal(1,"Shadow preset step%0d",i);
   tap(620,50);tap(700,300);expect_page(4);if(mode!=2||index!=i)$fatal(1,"Presets destroyed saved manual K step%0d",i);
'''+s[a:]
s=s.replace('if(image_mode!=7)$fatal(1,"Unused slot must not change selection")','if(image_mode!=1)$fatal(1,"Gray filter")')
s=s.replace('if(image_mode!=7)$fatal(1,"Removed row must not select a filter")','if(image_mode!=2)$fatal(1,"Cartoon filter")')
s=s.replace('if(image_mode!=7)$fatal(1,"Removed row must stay empty")','if(image_mode!=3)$fatal(1,"Negative filter")')
s=s.replace('if(image_mode!=7)$fatal(1,"Column gap must not select a filter")','if(image_mode!=3)$fatal(1,"Column gap must not select a filter")')
s=s.replace('if(image_mode!=7)$fatal(1,"Exclusive bottom boundary")','if(image_mode!=3)$fatal(1,"Exclusive bottom boundary")')
s=s.replace('if(image_mode!=7)$fatal(1,"Filter memory lost after navigation")','if(image_mode!=3)$fatal(1,"Filter memory lost after navigation")')
s=s.replace('PASS UI two-mode AWB/manual only, all 76 K steps retained across AWB, no removed preset page/rows, left-swipe release opening, inactive long press, filters, shared gain and fault cancellation','PASS UI three-mode WB and four environment presets; all 76 manual K steps retained across every preset and AWB; exact WB hitboxes, left-swipe release opening, inactive long press, all eight display choices, shared gain and fault cancellation')
s=s.replace('if(py==200)compare(half(mode==2?', 'if(py==200)compare(half(mode==1?')
s=s.replace('if(py==280||py==360||py==440)compare(half(24\'h111e2c,VIDEO));','if(py==280)compare(half(mode==2?24\'h087f83:24\'h26394d,VIDEO));\n    if(py==360||py==440)compare(half(24\'h111e2c,VIDEO));')
s=s.replace('PASS four complete WB UI frames: AWB/manual two-option selected states, removed rows transparent, manual10000K, 26 independent alpha/bar/preview probes, fixed control latency and frame-atomic mode/page','PASS four complete WB UI frames: AWB/manual selected states across three WB choices, manual10000K, 26 independent alpha/bar/preview probes, fixed control latency and frame-atomic mode/page')
p.write_text(s)
(r/'rgb/ui_test.sv').write_text(s)
for rel in ['isp/histogram_ui_tb.sv']:
 p=r/rel;s=p.read_text();s=s.replace('tap(700,140);tap(700,140);tap(700,220);','tap(700,140);tap(700,140);tap(700,300);')
 s=s.replace('tap(620,50);tap(700,220);if(page!=4','tap(620,50);tap(700,300);if(page!=4')
 s=s.replace('tap(900,380);if(filter!=7)$fatal(1,"Deleted filter row remains active");','tap(900,300);if(filter!=1)$fatal(1,"Gray restored");\n  tap(680,380);if(filter!=2)$fatal(1,"Cartoon restored");\n  tap(900,380);if(filter!=3)$fatal(1,"Negative restored");')
 s=s.replace('WB two-mode/manual-K independence and four-filter navigation plus original image','WB manual-K independence and restored display-choice navigation')
 p.write_text(s)
for rel in ['isp/tint_tb.sv','rgb/tint_tb.sv']:
 p=r/rel;s=p.read_text().replace('tap(700,220);if(page!=4','tap(700,300);if(page!=4').replace('tap(620,50);tap(700,220);tap(800,500)','tap(620,50);tap(700,300);tap(800,500)');p.write_text(s)
for rel in ['isp/red_target_tb.sv','rgb/target_ui_tb.sv']:
 p=r/rel;s=p.read_text().replace('lift();tap(700,140);tap(700,140);tap(700,220);','lift();tap(700,140);tap(700,140);tap(700,300);')
 s=s.replace('Removed WB preset config slot must stay zero','Reserved WB config slot must stay zero')
 s=s.replace('tap(620,50);tap(700,300);if(page!=1||mode!=2)$fatal(1,"Old manual row must have no action");','tap(620,50);tap(700,220);if(page!=3||mode!=2)$fatal(1,"Preset selector entry keeps active configuration");\n  tap(700,140);if(mode!=1||index!=5||!enabled)$fatal(1,"Preset keeps recognition independent");tap(620,50);')
 p.write_text(s)
p=r/'rgb/effects_ui_tb.sv';s=p.read_text().replace('tap(700,220);if(page!=4)$fatal(1,"Manual WB second row");','tap(700,300);if(page!=4)$fatal(1,"Manual WB third row");')
s=s.replace('  tap(620,50);tap(700,140);tap(700,140);if(page!=1)', '  tap(900,300);coherent();if(image_mode!=1)$fatal(1,"Gray");\n  tap(680,380);coherent();if(image_mode!=2)$fatal(1,"Cartoon");\n  tap(900,380);coherent();if(image_mode!=3)$fatal(1,"Negative");\n  tap(620,50);tap(700,140);tap(700,140);if(page!=1)')
s=s.replace('PASS five retained filters, coherent 52-bit mailbox and two-choice AWB/manual navigation','PASS all eight display choices, coherent 52-bit mailbox and three-choice WB navigation');p.write_text(s)
# Sorted glyph IDs change after restoration; a frozen RTL reference needs its own original assets.
a=r/'qualified_ui_assets';a.mkdir(exist_ok=True)
g=Path('optimization_20261027/delivery_qualified/ISP_RGB_SC500_INTEGRATED/user_source/hdl_source/ui')
for n in ['wb_ui_font.hex','wb_ui_text.hex']:(a/n).write_bytes((g/n).read_bytes())
p=r/'ui_optimized_equivalence_tb.sv';s=p.read_text();a=s.index(' optimization_reference_ui_overlay');s=s[:a]+s[a:].replace('../../user_source/hdl_source/ui/','../qualified_ui_assets/',2);p.write_text(s)
print('Updated tests only; RTL unchanged')
