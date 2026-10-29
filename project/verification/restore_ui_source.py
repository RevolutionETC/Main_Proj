from pathlib import Path
r=Path('res27')
def edit(path,replacements):
    p=r/path;s=p.read_text(encoding='utf-8-sig')
    for old,new in replacements:
        assert old in s,(path,old[:100])
        s=s.replace(old,new,1)
    p.write_text(s,encoding='utf8')
edit(Path('user_source/hdl_source/ui/wb_ui_control.v'),[
 ("reg inc_req,dec_req,reset_gain;reg [1:0] gain_preset;","reg inc_req,dec_req,reset_gain;reg [1:0] gain_preset;\n reg [6:0] custom_index; // Manual K survives AWB and environmental shortcuts."),
 ("O_show_meter<=0;O_page<=0;O_mode<=0;O_index<=30;","O_show_meter<=0;O_page<=0;O_mode<=0;O_index<=30;custom_index<=30;"),
 ("else if(I_y>=192&&I_y<256)begin O_page<=4;O_mode<=2;end","else if(I_y>=192&&I_y<256)O_page<=3;\n        else if(I_y>=272&&I_y<336)begin O_page<=4;O_mode<=2;O_index<=custom_index;end"),
 ("2:;\n       4:begin","2:;\n       // Presets reuse the existing Kelvin gain LUT and do not overwrite manual K.\n       3:if(I_x>=584&&I_x<1000)begin\n        if(I_y>=112&&I_y<176)begin O_mode<=1;O_index<=5;end\n        else if(I_y>=192&&I_y<256)begin O_mode<=1;O_index<=30;end\n        else if(I_y>=272&&I_y<336)begin O_mode<=1;O_index<=40;end\n        else if(I_y>=352&&I_y<416)begin O_mode<=1;O_index<=50;end\n       end\n       4:begin"),
 ("drag<=1;O_index<=slider_index(I_x);","drag<=1;O_index<=slider_index(I_x);custom_index<=slider_index(I_x);"),
 ("if(drag)O_index<=slider_index(I_x);","if(drag)begin O_index<=slider_index(I_x);custom_index<=slider_index(I_x);end"),
 ("if(I_x>=584&&I_x<784)O_image_mode<=7;\n        end","if(I_x>=584&&I_x<784)O_image_mode<=7;\n         else if(I_x>=800&&I_x<1000)O_image_mode<=1;\n        end else if(I_y>=352&&I_y<416)begin\n         if(I_x>=584&&I_x<784)O_image_mode<=2;\n         else if(I_x>=800&&I_x<1000)O_image_mode<=3;\n        end")
])
edit(Path('tools/wb_ui_overlay.template.v'),[
 ("wire [3:0] page=active[25:22];wire manual_mode=active[21];","wire [3:0] page=active[25:22];wire [1:0] wb_mode=active[21:20];wire manual_mode=wb_mode==2;"),
 ("// Reuse the removed WB-preset field: bit 18 hides both information bars.","// Bit 18 retains the bar setting. Preset selection is derived from the Kelvin index."),
 ("label(manual_mode?3:1,176,20,8);\n    if(manual_mode)label(28,400,20,6);","label(wb_mode==0?1:wb_mode==1?2:3,176,20,8);\n    if(wb_mode!=0)label(28,400,20,6);"),
 ("label(image_mode==4?59:image_mode==5?60:image_mode==6?63:image_mode==7?38:55,600,20,4);","label(image_mode==1?56:image_mode==2?57:image_mode==3?58:image_mode==4?59:image_mode==5?60:image_mode==6?63:image_mode==7?38:55,600,20,4);"),
 ("page==2?7:page==4?9:","page==2?7:page==3?8:page==4?9:"),
 ("""    1:begin
     if(in_rect(x,y,584,112,1000,176))background_code=!manual_mode?5'd2:5'd9;
     if(in_rect(x,y,584,192,1000,256))background_code=manual_mode?5'd2:5'd9;
     label(7,620,132,5);label(9,620,212,5);
    end""","""    1:begin
     if(in_rect(x,y,584,112,1000,176))background_code=wb_mode==0?5'd2:5'd9;
     if(in_rect(x,y,584,192,1000,256))background_code=wb_mode==1?5'd2:5'd9;
     if(in_rect(x,y,584,272,1000,336))background_code=wb_mode==2?5'd2:5'd9;
     label(7,620,132,5);label(8,620,212,4);label(9,620,292,5);
    end"""),
 ("    4:begin\n     label(19,600,116,9);","""    3:begin
     if(in_rect(x,y,584,112,1000,176))background_code=(wb_mode==1&&index==5)?5'd2:5'd9;
     if(in_rect(x,y,584,192,1000,256))background_code=(wb_mode==1&&index==30)?5'd2:5'd9;
     if(in_rect(x,y,584,272,1000,336))background_code=(wb_mode==1&&index==40)?5'd2:5'd9;
     if(in_rect(x,y,584,352,1000,416))background_code=(wb_mode==1&&index==50)?5'd2:5'd9;
     label(15,620,132,12);label(16,620,212,8);label(17,620,292,8);label(18,620,372,8);
     label(14,600,464,6);
    end
    4:begin
     label(19,600,116,9);"""),
 ("""     if(in_rect(x,y,584,272,784,336))background_code=(image_mode==7)?5'd2:5'd9;
     label(55,648,132,2);label(60,864,132,2);
     label(59,636,212,3);label(63,864,212,2);
     label(38,636,292,4);""","""     if(in_rect(x,y,584,272,784,336))background_code=(image_mode==7)?5'd2:5'd9;
     if(in_rect(x,y,800,272,1000,336))background_code=(image_mode==1)?5'd2:5'd9;
     if(in_rect(x,y,584,352,784,416))background_code=(image_mode==2)?5'd2:5'd9;
     if(in_rect(x,y,800,352,1000,416))background_code=(image_mode==3)?5'd2:5'd9;
     label(55,648,132,2);label(60,864,132,2);
     label(59,636,212,3);label(63,864,212,2);
     label(38,636,292,4);label(56,864,292,2);
     label(57,648,372,2);label(58,864,372,2);""")
])
edit(Path('tools/generate_wb_ui.py'),[
 ("# Empty entries retain the label IDs of the removed white-balance presets.","# Stable label IDs preserve the existing information, feature and filter pages."),
 ("labels[35]=''  # Target tracking belongs only to the feature library.","""labels[35]=''  # Target tracking belongs only to the feature library.
# Restore environmental shortcuts and the three inexpensive display choices.
labels[2]='模式：环境预设';labels[8]='环境预设';labels[14]='选择光照环境'
labels[15]='暖色灯光 3000K';labels[16]='日光 5500K';labels[17]='阴天 6500K';labels[18]='阴影 7500K'
labels[56]='黑白';labels[57]='动漫';labels[58]='负片'""")
])
print('Restored UI/controller source; 52-bit config and bar bit18 preserved')
