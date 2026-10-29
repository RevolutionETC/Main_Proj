// Demonstration starting gains, NOT sensor-calibrated absolute CCT. Q10.
module wb_gain_lut(input wire [6:0] I_index,output reg [11:0] O_r,O_b);
always @(*)begin
case(I_index)
7'd0:begin O_r=12'd640;O_b=12'd2458;end // 2500 K
7'd1:begin O_r=12'd655;O_b=12'd2376;end // 2600 K
7'd2:begin O_r=12'd671;O_b=12'd2294;end // 2700 K
7'd3:begin O_r=12'd686;O_b=12'd2212;end // 2800 K
7'd4:begin O_r=12'd702;O_b=12'd2130;end // 2900 K
7'd5:begin O_r=12'd717;O_b=12'd2048;end // 3000 K
7'd6:begin O_r=12'd731;O_b=12'd1997;end // 3100 K
7'd7:begin O_r=12'd746;O_b=12'd1946;end // 3200 K
7'd8:begin O_r=12'd760;O_b=12'd1894;end // 3300 K
7'd9:begin O_r=12'd774;O_b=12'd1843;end // 3400 K
7'd10:begin O_r=12'd788;O_b=12'd1792;end // 3500 K
7'd11:begin O_r=12'd803;O_b=12'd1741;end // 3600 K
7'd12:begin O_r=12'd817;O_b=12'd1690;end // 3700 K
7'd13:begin O_r=12'd831;O_b=12'd1638;end // 3800 K
7'd14:begin O_r=12'd846;O_b=12'd1587;end // 3900 K
7'd15:begin O_r=12'd860;O_b=12'd1536;end // 4000 K
7'd16:begin O_r=12'd871;O_b=12'd1502;end // 4100 K
7'd17:begin O_r=12'd882;O_b=12'd1468;end // 4200 K
7'd18:begin O_r=12'd893;O_b=12'd1434;end // 4300 K
7'd19:begin O_r=12'd904;O_b=12'd1399;end // 4400 K
7'd20:begin O_r=12'd915;O_b=12'd1365;end // 4500 K
7'd21:begin O_r=12'd926;O_b=12'd1331;end // 4600 K
7'd22:begin O_r=12'd937;O_b=12'd1297;end // 4700 K
7'd23:begin O_r=12'd947;O_b=12'd1263;end // 4800 K
7'd24:begin O_r=12'd958;O_b=12'd1229;end // 4900 K
7'd25:begin O_r=12'd969;O_b=12'd1195;end // 5000 K
7'd26:begin O_r=12'd980;O_b=12'd1161;end // 5100 K
7'd27:begin O_r=12'd991;O_b=12'd1126;end // 5200 K
7'd28:begin O_r=12'd1002;O_b=12'd1092;end // 5300 K
7'd29:begin O_r=12'd1013;O_b=12'd1058;end // 5400 K
7'd30:begin O_r=12'd1024;O_b=12'd1024;end // 5500 K
7'd31:begin O_r=12'd1035;O_b=12'd1012;end // 5600 K
7'd32:begin O_r=12'd1047;O_b=12'd999;end // 5700 K
7'd33:begin O_r=12'd1058;O_b=12'd987;end // 5800 K
7'd34:begin O_r=12'd1069;O_b=12'd975;end // 5900 K
7'd35:begin O_r=12'd1080;O_b=12'd962;end // 6000 K
7'd36:begin O_r=12'd1092;O_b=12'd950;end // 6100 K
7'd37:begin O_r=12'd1103;O_b=12'd938;end // 6200 K
7'd38:begin O_r=12'd1114;O_b=12'd926;end // 6300 K
7'd39:begin O_r=12'd1126;O_b=12'd913;end // 6400 K
7'd40:begin O_r=12'd1137;O_b=12'd901;end // 6500 K
7'd41:begin O_r=12'd1146;O_b=12'd893;end // 6600 K
7'd42:begin O_r=12'd1155;O_b=12'd885;end // 6700 K
7'd43:begin O_r=12'd1165;O_b=12'd876;end // 6800 K
7'd44:begin O_r=12'd1174;O_b=12'd868;end // 6900 K
7'd45:begin O_r=12'd1183;O_b=12'd860;end // 7000 K
7'd46:begin O_r=12'd1192;O_b=12'd852;end // 7100 K
7'd47:begin O_r=12'd1201;O_b=12'd844;end // 7200 K
7'd48:begin O_r=12'd1211;O_b=12'd835;end // 7300 K
7'd49:begin O_r=12'd1220;O_b=12'd827;end // 7400 K
7'd50:begin O_r=12'd1229;O_b=12'd819;end // 7500 K
7'd51:begin O_r=12'd1237;O_b=12'd815;end // 7600 K
7'd52:begin O_r=12'd1245;O_b=12'd811;end // 7700 K
7'd53:begin O_r=12'd1254;O_b=12'd807;end // 7800 K
7'd54:begin O_r=12'd1262;O_b=12'd803;end // 7900 K
7'd55:begin O_r=12'd1270;O_b=12'd799;end // 8000 K
7'd56:begin O_r=12'd1278;O_b=12'd795;end // 8100 K
7'd57:begin O_r=12'd1286;O_b=12'd790;end // 8200 K
7'd58:begin O_r=12'd1295;O_b=12'd786;end // 8300 K
7'd59:begin O_r=12'd1303;O_b=12'd782;end // 8400 K
7'd60:begin O_r=12'd1311;O_b=12'd778;end // 8500 K
7'd61:begin O_r=12'd1319;O_b=12'd774;end // 8600 K
7'd62:begin O_r=12'd1327;O_b=12'd770;end // 8700 K
7'd63:begin O_r=12'd1336;O_b=12'd766;end // 8800 K
7'd64:begin O_r=12'd1344;O_b=12'd762;end // 8900 K
7'd65:begin O_r=12'd1352;O_b=12'd758;end // 9000 K
7'd66:begin O_r=12'd1360;O_b=12'd754;end // 9100 K
7'd67:begin O_r=12'd1368;O_b=12'd750;end // 9200 K
7'd68:begin O_r=12'd1377;O_b=12'd746;end // 9300 K
7'd69:begin O_r=12'd1385;O_b=12'd741;end // 9400 K
7'd70:begin O_r=12'd1393;O_b=12'd737;end // 9500 K
7'd71:begin O_r=12'd1401;O_b=12'd733;end // 9600 K
7'd72:begin O_r=12'd1409;O_b=12'd729;end // 9700 K
7'd73:begin O_r=12'd1418;O_b=12'd725;end // 9800 K
7'd74:begin O_r=12'd1426;O_b=12'd721;end // 9900 K
7'd75:begin O_r=12'd1434;O_b=12'd717;end // 10000 K
default:begin O_r=12'd1024;O_b=12'd1024;end
endcase
end
endmodule
