from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
w=Path(__file__).resolve().parent.parent;r=w/'user_source/hdl_source'
# Stable label IDs preserve the existing information, feature and filter pages.
labels=['白平衡演示','模式：自动','','模式：手动','长按画面进入设置','回退','白平衡设置','自动白平衡','','手动白平衡','感光度','自动模式已启用','自动适应环境光','切换光源后稍候','','','','','','拖动滑条调节色温','2500K','10000K','感光度','减少','增加','恢复默认','触屏未连接','实时预览','','','每格 100K','实体按键同步可用','1倍','2倍','4倍','目标识别','开启','关闭','视觉增强','色彩偏移','归零','统计有效','等待稳定帧','B','A','G','M','','','','','','按键','滤镜库','功能库','原图','黑白','动漫','负片','像素画','边缘','OSD 水印','目标跟踪','复古']
labels+=['ISP','设置','自动曝光','直方图均衡（待实现）','锁定曝光','快门','等待测光','调节中','已稳定','达到极限','固定感光度','自动调节快门','']
labels+=['点测光','中央重点测光','手动感光度','手动调节已启用']
labels+=['评价测光','局部测光','显示测光']
labels+=['直方图均衡','自动','手动','均衡强度','','输入亮度直方图','峰值100%','0','255','等待有效帧','上一有效帧','拖动调节强度','自动计算']
for n in [0,11,12,13,22,56,58,67,68,69,74,75]:labels[n]=''
labels[35]=''  # Target tracking belongs only to the feature library.
# Restore environmental shortcuts and the three inexpensive display choices.
labels[2]='模式：环境预设';labels[8]='环境预设';labels[14]='选择光照环境'
labels[15]='暖色灯光 3000K';labels[16]='日光 5500K';labels[17]='阴天 6500K';labels[18]='阴影 7500K'
labels[56]='黑白';labels[57]='动漫';labels[58]='负片'
assert len(labels)==97
labels+=['上下边栏','隐藏','显示']
labels[4]='左滑画面进入设置'
assert len(labels)==100
labels+=['画面信息','当前帧龄','峰值帧龄','丢弃帧数','读取溢出','显示欠读','','','','','','计数上限255']
chars=sorted(set(''.join(labels)+'0123456789K增益 /.倍RBAGMms%-'))
assert len(chars)<=256
ids={c:i for i,c in enumerate(chars)}
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
data=[]
for c in chars:
    im=Image.new('L',(24,24));d=ImageDraw.Draw(im)
    box=d.textbbox((0,0),c,font=font)
    d.text(((24-(box[2]-box[0]))//2-box[0],(24-(box[3]-box[1]))//2-box[1]),c,font=font,fill=255)
    for y in range(32):
        value=0
        for x in range(24):value=(value<<1)|int(y<24 and im.getpixel((x,y))>=100)
        data.append(f'{value:06x}')
(r/'ui/wb_ui_font.hex').write_bytes(('\n'.join(data)+'\n').encode('ascii'))
(r/'ui/wb_ui_font.v').write_bytes(f'''module wb_ui_font #(parameter FONT_FILE="../../../user_source/hdl_source/ui/wb_ui_font.hex")(
 input wire I_clk,input wire [12:0] I_addr,output reg [23:0] O_bits);
 (* ram_style="block" *) reg [23:0] font[0:{len(data)-1}];
 initial $readmemh(FONT_FILE,font);
 always @(posedge I_clk)O_bits<=font[I_addr];
endmodule
'''.encode('utf-8'))
f='    function [7:0] glyph(input [6:0] text_id,input [5:0] pos);\n        reg [11:0] diagnostic_digits;\n        begin\n            diagnostic_digits=text_id==106?dec_age:text_id==107?dec_peak:text_id==108?dec_drop:text_id==109?dec_overflow:dec_underflow;\n            glyph=8\'d'+str(ids[' '])+';\n            case(text_id)\n'
assert max(map(len,labels))<=16 and len(labels)<=128
text=[ids[' ']]*(128*16)
for i,label in enumerate(labels):
    for j,c in enumerate(label):text[i*16+j]=ids[c]
(r/'ui/wb_ui_text.hex').write_text(''.join(f'{v:02x}\n' for v in text),encoding='ascii')
(r/'ui/wb_ui_text_rom.v').write_text('''module wb_ui_text_rom #(parameter TEXT_FILE="../../../user_source/hdl_source/ui/wb_ui_text.hex")(
 input wire I_clk,input wire [10:0] I_addr,output reg [7:0] O_glyph);
 (* ram_style="block" *) reg [7:0] text[0:2047];
 initial $readmemh(TEXT_FILE,text);
 always @(posedge I_clk)O_glyph<=text[I_addr];
endmodule
''',encoding='utf-8')
f+='''            7'd106,7'd107,7'd108,7'd109,7'd110:case(pos)
                0:glyph=(text_id==106&&!latency_valid)?CHAR_MINUS:digit_glyph(diagnostic_digits[11:8]);
                1:glyph=(text_id==106&&!latency_valid)?CHAR_MINUS:digit_glyph(diagnostic_digits[7:4]);
                2:glyph=(text_id==106&&!latency_valid)?CHAR_MINUS:digit_glyph(diagnostic_digits[3:0]);
                default:;endcase
            7'd88:case(pos)
                0:if(hist_strength>=100)glyph=DIGIT_1;
                1:if(hist_strength>=10)glyph=digit_glyph((hist_strength/10)%10);
                2:glyph=digit_glyph(hist_strength%10);
                3:glyph=CHAR_PERCENT;
                default:;endcase
            6'd28:case(pos)
                0:if(k_units>=100)glyph=DIGIT_1;
                1:glyph=digit_glyph((k_units/10)%10);
                2:glyph=digit_glyph(k_units%10);
                3,4:glyph=DIGIT_0;
                5:glyph=LETTER_K;
                default:;endcase
            6'd29:case(pos)
                0:glyph=digit_glyph(dec_gain[11:8]);
                1:glyph=CHAR_DOT;
                2:glyph=digit_glyph(dec_gain[7:4]);
                3:glyph=digit_glyph(dec_gain[3:0]);
                4:glyph=CHAR_BEI;
                default:;endcase
            6'd47,6'd48,6'd49:case(pos)
                0:glyph=(text_id==47)?CHAR_R:(text_id==48)?CHAR_G:CHAR_B;
                2:glyph=digit_glyph(((text_id==47)?dec_r[11:8]:(text_id==48)?dec_g[11:8]:dec_b[11:8]));
                3:glyph=CHAR_DOT;
                4:glyph=digit_glyph(((text_id==47)?dec_r[7:4]:(text_id==48)?dec_g[7:4]:dec_b[7:4]));
                5:glyph=digit_glyph(((text_id==47)?dec_r[3:0]:(text_id==48)?dec_g[3:0]:dec_b[3:0]));
                6:glyph=CHAR_BEI;
                default:;endcase
            6'd52:case(pos)
                0:glyph=CHAR_AN;1:glyph=CHAR_JIAN;
                3:glyph=active[38]?CHAR_G:CHAR_B;
                4:glyph=active[38]?CHAR_M:CHAR_A;
                default:;endcase
            6'd50:case(pos)
                0:glyph=ab<0?CHAR_B:CHAR_A;
                1:glyph=digit_glyph(ab<0?-ab:ab);
                default:;endcase
            6'd51:case(pos)
                0:glyph=gm<0?CHAR_M:CHAR_G;
                1:glyph=digit_glyph(gm<0?-gm:gm);
                default:;endcase
            default:;
            endcase
        end
    endfunction
'''
f=f.replace('{ms_m}',str(ids['m'])).replace('{ms_s}',str(ids['s']))
constants=''
for name,c in [('CHAR_MINUS','-'),('CHAR_PERCENT','%'),('DIGIT_0','0'),('DIGIT_1','1'),('DIGIT_7','7'),('DIGIT_3','3'),('LETTER_K','K'),('CHAR_ZENG','增'),('CHAR_YI','益'),('CHAR_SLASH','/'),('CHAR_DOT','.'),('CHAR_BEI','倍'),('CHAR_R','R'),('CHAR_G','G'),('CHAR_B','B'),('CHAR_A','A'),('CHAR_M','M'),('CHAR_AN','按'),('CHAR_JIAN','键')]:constants+=f"    localparam [7:0] {name}=8'd{ids[c]};\n"
constants+='    function [7:0] digit_glyph(input [3:0] n);begin case(n)\n'
for n in range(10):constants+=f"        4'd{n}:digit_glyph=8'd{ids[str(n)]};\n"
constants+=f"        default:digit_glyph=8'd{ids[' ']};endcase end endfunction\n"
template=(w/'tools/wb_ui_overlay.template.v').read_text(encoding='utf-8')
(r/'ui/wb_ui_overlay.v').write_bytes(template.replace('// GENERATED_GLYPHS',constants+f).encode('utf-8'))
print(f'Generated {len(chars)} glyphs, {len(data)*24} font bits; Kelvin LUT unchanged')
