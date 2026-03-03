`timescale 1ns / 1ps

module ascon_accelerator(
    input         PCLK,
    input         PRESETn,
    input  [31:0] PADDR,
    input         PSEL,
    input         PENABLE,
    input         PWRITE,
    input  [31:0] PWDATA,
    output reg [31:0] PRDATA,
    output        PREADY,
    output        PSLVERR
);

assign PREADY  = 1'b1;
assign PSLVERR = 1'b0;

// --------------------------------------------------
// Registers
// --------------------------------------------------
reg [31:0] control_reg;
reg [31:0] status_reg;

reg [63:0] data_in;
reg [63:0] data_out;

reg [127:0] key;
reg [127:0] nonce;

reg [127:0] tag;       // generated tag
reg [127:0] tag_in;    // received tag (for decrypt)

reg tag_valid;

reg [63:0] x0, x1, x2, x3, x4;

reg start;
reg decrypt;
reg busy;
reg done;

reg [3:0] state;
reg [3:0] round;

// --------------------------------------------------
// FSM STATES
// --------------------------------------------------
parameter IDLE          = 4'd0;
parameter LOAD_INIT     = 4'd1;
parameter INIT_PERMUTE  = 4'd2;
parameter INIT_KEY_XOR  = 4'd3;
parameter PT_PROCESS    = 4'd4;
parameter FINAL_KEY_XOR = 4'd5;
parameter FINAL_PERMUTE = 4'd6;
parameter TAG_OUT       = 4'd7;
parameter TAG_VERIFY    = 4'd8;
parameter DONE_STATE    = 4'd9;

parameter [63:0] IV = 64'h80400c0600000000;

// --------------------------------------------------
// ROUND SELECT
// --------------------------------------------------
wire [3:0] round_sel;
assign round_sel = (state == PT_PROCESS) ? (round + 4'd6) : round;

// --------------------------------------------------
// ROUND INSTANCE
// --------------------------------------------------
wire [63:0] nx0, nx1, nx2, nx3, nx4;

ascon_round round_inst (
    .x0_in(x0),
    .x1_in(x1),
    .x2_in(x2),
    .x3_in(x3),
    .x4_in(x4),
    .round(round_sel),
    .x0_out(nx0),
    .x1_out(nx1),
    .x2_out(nx2),
    .x3_out(nx3),
    .x4_out(nx4)
);

// --------------------------------------------------
// APB WRITE
// --------------------------------------------------
wire write_en = PSEL & PENABLE & PWRITE;

always @(posedge PCLK) begin
    if(!PRESETn) begin
        control_reg <= 0;
        data_in <= 0;
        key <= 0;
        nonce <= 0;
        tag_in <= 0;
    end
    else if(write_en) begin
        case(PADDR[7:0])

            8'h00: control_reg <= PWDATA;

            8'h08: data_in[31:0]  <= PWDATA;
            8'h0C: data_in[63:32] <= PWDATA;

            8'h18: key[31:0]   <= PWDATA;
            8'h1C: key[63:32]  <= PWDATA;
            8'h20: key[95:64]  <= PWDATA;
            8'h24: key[127:96] <= PWDATA;

            8'h28: nonce[31:0]   <= PWDATA;
            8'h2C: nonce[63:32]  <= PWDATA;
            8'h30: nonce[95:64]  <= PWDATA;
            8'h34: nonce[127:96] <= PWDATA;

            // Tag input (for decrypt)
            8'h48: tag_in[31:0]   <= PWDATA;
            8'h4C: tag_in[63:32]  <= PWDATA;
            8'h50: tag_in[95:64]  <= PWDATA;
            8'h54: tag_in[127:96] <= PWDATA;

        endcase
    end
end

// --------------------------------------------------
// APB READ
// --------------------------------------------------
always @(posedge PCLK) begin
    if(!PRESETn)
        PRDATA <= 0;
    else if(PSEL && PENABLE && !PWRITE) begin
        case(PADDR[7:0])

            8'h04: PRDATA <= status_reg;

            8'h10: PRDATA <= data_out[31:0];
            8'h14: PRDATA <= data_out[63:32];

            8'h38: PRDATA <= tag[31:0];
            8'h3C: PRDATA <= tag[63:32];
            8'h40: PRDATA <= tag[95:64];
            8'h44: PRDATA <= tag[127:96];

            default: PRDATA <= 32'b0;
        endcase
    end
end

// --------------------------------------------------
// CONTROL
// --------------------------------------------------
always @(posedge PCLK) begin
    if(!PRESETn) begin
        start <= 0;
        decrypt <= 0;
        status_reg <= 0;
    end else begin
        start   <= control_reg[0] & ~busy;
        decrypt <= control_reg[1];

        // status: [tag_valid | busy | done]
        status_reg <= {29'b0, tag_valid, busy, done};
    end
end

// --------------------------------------------------
// FSM
// --------------------------------------------------
always @(posedge PCLK) begin
    if(!PRESETn) begin
        state <= IDLE;
        round <= 0;
        done  <= 0;
        busy  <= 0;
        tag_valid <= 0;

        x0 <= 0; x1 <= 0; x2 <= 0; x3 <= 0; x4 <= 0;
        data_out <= 0;
        tag <= 0;
    end
    else begin

        case(state)

        IDLE: begin
            done <= 0;
            busy <= 0;
            tag_valid <= 0;
            round <= 0;
            if(start)
                state <= LOAD_INIT;
        end

        LOAD_INIT: begin
            busy <= 1;
            x0 <= IV;
            x1 <= key[127:64];
            x2 <= key[63:0];
            x3 <= nonce[127:64];
            x4 <= nonce[63:0];
            round <= 0;
            state <= INIT_PERMUTE;
        end

        INIT_PERMUTE: begin
            if(round < 12) begin
                x0 <= nx0; x1 <= nx1; x2 <= nx2; x3 <= nx3; x4 <= nx4;
                round <= round + 1;
            end else begin
                round <= 0;
                state <= INIT_KEY_XOR;
            end
        end

        INIT_KEY_XOR: begin
            x3 <= x3 ^ key[127:64];
            x4 <= x4 ^ key[63:0];
            state <= PT_PROCESS;
        end

        PT_PROCESS: begin
            if(round == 0) begin

                if(decrypt) begin
                    data_out <= x0 ^ data_in;  // recover plaintext
                    x0 <= data_in;             // absorb ciphertext
                end else begin
                    data_out <= x0 ^ data_in;  // produce ciphertext
                    x0 <= x0 ^ data_in;        // absorb plaintext
                end

                round <= 1;
            end
            else if(round <= 6) begin
                x0 <= nx0; x1 <= nx1; x2 <= nx2; x3 <= nx3; x4 <= nx4;
                round <= round + 1;
            end
            else begin
                round <= 0;
                state <= FINAL_KEY_XOR;
            end
        end

        FINAL_KEY_XOR: begin
            x1 <= x1 ^ key[127:64];
            x2 <= x2 ^ key[63:0];
            state <= FINAL_PERMUTE;
        end

        FINAL_PERMUTE: begin
            if(round < 12) begin
                x0 <= nx0; x1 <= nx1; x2 <= nx2; x3 <= nx3; x4 <= nx4;
                round <= round + 1;
            end else begin
                round <= 0;
                state <= TAG_OUT;
            end
        end

        TAG_OUT: begin
            tag[127:64] <= x3 ^ key[127:64];
            tag[63:0]   <= x4 ^ key[63:0];

            if(decrypt)
                state <= TAG_VERIFY;
            else
                state <= DONE_STATE;
        end

        TAG_VERIFY: begin
            if(tag == tag_in)
                tag_valid <= 1;
            else
                tag_valid <= 0;

            state <= DONE_STATE;
        end

        DONE_STATE: begin
            done <= 1;
            busy <= 0;
        end

        endcase
    end
end

endmodule
