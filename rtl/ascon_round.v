`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2026 05:01:54 PM
// Design Name: 
// Module Name: ascon_round
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ascon_round (
    input  [63:0] x0_in,
    input  [63:0] x1_in,
    input  [63:0] x2_in,
    input  [63:0] x3_in,
    input  [63:0] x4_in,
    input  [3:0]  round,

    output [63:0] x0_out,
    output [63:0] x1_out,
    output [63:0] x2_out,
    output [63:0] x3_out,
    output [63:0] x4_out
);

reg [63:0] x0, x1, x2, x3, x4;
reg [7:0] rc;
reg [63:0] t0, t1, t2, t3, t4;

function [63:0] rotr;
    input [63:0] x;
    input [5:0] n;
    begin
        rotr = (x >> n) | (x << (64-n));
    end
endfunction

always @(*) begin

    // load inputs
    x0 = x0_in;
    x1 = x1_in;
    x2 = x2_in;
    x3 = x3_in;
    x4 = x4_in;

    // =====================
    // pC (constant addition)
    // =====================
    case(round)
        4'd0:  rc = 8'hf0;
        4'd1:  rc = 8'he1;
        4'd2:  rc = 8'hd2;
        4'd3:  rc = 8'hc3;
        4'd4:  rc = 8'hb4;
        4'd5:  rc = 8'ha5;
        4'd6:  rc = 8'h96;
        4'd7:  rc = 8'h87;
        4'd8:  rc = 8'h78;
        4'd9:  rc = 8'h69;
        4'd10: rc = 8'h5a;
        4'd11: rc = 8'h4b;
        default: rc = 8'h00;
    endcase

    x2 = x2 ^ {56'b0, rc};

    // =====================
    // pS (S-box)
    // =====================
    x0 = x0 ^ x4;
    x4 = x4 ^ x3;
    x2 = x2 ^ x1;

    t0 = ~x0 & x1;
    t1 = ~x1 & x2;
    t2 = ~x2 & x3;
    t3 = ~x3 & x4;
    t4 = ~x4 & x0;

    x0 = x0 ^ t1;
    x1 = x1 ^ t2;
    x2 = x2 ^ t3;
    x3 = x3 ^ t4;
    x4 = x4 ^ t0;

    x1 = x1 ^ x0;
    x0 = x0 ^ x4;
    x3 = x3 ^ x2;
    x2 = ~x2;

    // =====================
    // pL (diffusion)
    // =====================
    x0 = x0 ^ rotr(x0,19) ^ rotr(x0,28);
    x1 = x1 ^ rotr(x1,61) ^ rotr(x1,39);
    x2 = x2 ^ rotr(x2,1)  ^ rotr(x2,6);
    x3 = x3 ^ rotr(x3,10) ^ rotr(x3,17);
    x4 = x4 ^ rotr(x4,7)  ^ rotr(x4,41);

end

assign x0_out = x0;
assign x1_out = x1;
assign x2_out = x2;
assign x3_out = x3;
assign x4_out = x4;

endmodule
