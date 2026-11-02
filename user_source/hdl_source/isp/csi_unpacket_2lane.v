
































`timescale 1ns / 1ns

module csi_unpacket_2lane 
(
input wire          I_clk,   
input wire          I_rst_n, 

(* keep = "true" *) input wire          I_hs_valid, 
(* keep = "true" *) input wire[15: 0]   I_hs_data,  

output reg           O_csi_frame_start,  
output reg           O_csi_frame_end,    
(* keep = "true" *) output reg           O_csi_valid,  
output reg           O_csi_hs,
output reg           O_csi_line_end,  
(* keep = "true" *) output reg  [31: 0]  O_csi_data    
);


 
 
 
 
 
 
 

localparam FRAME_DATA_DT  = 8'h2B;    
 
localparam FRAME_START_DT = 8'h00;
localparam FRAME_END_DT   = 8'h01;

(* keep = "true" *) reg        S_hs_valid_1d;       
(* keep = "true" *) reg [15:0] S_hs_data_1d;        
(* keep = "true" *) wire       S_head_en;           
(* keep = "true" *) reg        S_head_en_1d;        
(* keep = "true" *) reg [15:0] S_data_length;       
(* keep = "true" *) reg        S_data_en;           
(* keep = "true" *) reg [15:0] S_data_en_cnt;       

assign  S_head_en  = ~S_hs_valid_1d & I_hs_valid; 

 
always @(posedge I_clk) begin 
    S_hs_valid_1d        <= I_hs_valid;
    S_hs_data_1d         <= I_hs_data;
    S_head_en_1d         <= S_head_en; 
end

 
always @(posedge I_clk) 
    O_csi_frame_start <= (S_head_en_1d && S_hs_data_1d[15:8] == FRAME_START_DT);


 
always @(posedge I_clk) 
    O_csi_frame_end  <= (S_head_en_1d && S_hs_data_1d[15:8] == FRAME_END_DT);

 
always @(posedge I_clk) begin 
    if(I_hs_valid)begin
        if(S_head_en_1d && S_hs_data_1d[15:8] == FRAME_DATA_DT)
            S_data_length <= {I_hs_data[15:8],S_hs_data_1d[7:0]} >> 1;
        else    
            S_data_length <= S_data_length;
    end
    else    
        S_data_length <= 'd0;
end


 
always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n)
        S_data_en <= 1'b0;
    else    
        if(S_head_en_1d && S_hs_data_1d[15:8] == FRAME_DATA_DT)
            S_data_en <= 1'b1;
        else if(S_data_en_cnt == S_data_length-1)
            S_data_en <= 1'b0;
        else    
            S_data_en <= S_data_en;
end

 
always @(posedge I_clk) begin
    if(S_data_en)
        S_data_en_cnt <= S_data_en_cnt + 'd1;
    else
        S_data_en_cnt <= 'd0;
end

 
(* keep = "true" *) reg  csi_valid_r; 

always @(posedge I_clk) begin
    csi_valid_r   <= S_data_en ? ~csi_valid_r : 0; 
    O_csi_valid   <= csi_valid_r;
    O_csi_hs      <= I_hs_valid; 
end

always @(posedge I_clk) begin
    O_csi_data    <= S_data_en ? {O_csi_data[15:0],I_hs_data} : 0;
end

    
 
 
reg payload_d;
always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin payload_d<=0;O_csi_line_end<=0;end
 else begin payload_d<=S_data_en;O_csi_line_end<=payload_d&&!S_data_en;end
endmodule