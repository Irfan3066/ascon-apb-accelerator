`timescale 1ns / 1ps

module tb_ascon_decryption;

// ---------------------------------
// APB Signals
// ---------------------------------
reg         PCLK;
reg         PRESETn;
reg  [31:0] PADDR;
reg         PSEL;
reg         PENABLE;
reg         PWRITE;
reg  [31:0] PWDATA;
wire [31:0] PRDATA;
wire        PREADY;
wire        PSLVERR;

// ---------------------------------
// DUT
// ---------------------------------
ascon_accelerator DUT (
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .PADDR(PADDR),
    .PSEL(PSEL),
    .PENABLE(PENABLE),
    .PWRITE(PWRITE),
    .PWDATA(PWDATA),
    .PRDATA(PRDATA),
    .PREADY(PREADY),
    .PSLVERR(PSLVERR)
);

// ---------------------------------
// CLOCK
// ---------------------------------
always #5 PCLK = ~PCLK;

// ---------------------------------
// APB WRITE
// ---------------------------------
task apb_write;
input [31:0] addr;
input [31:0] data;
begin
    @(posedge PCLK);
    PADDR   = addr;
    PWDATA  = data;
    PWRITE  = 1;
    PSEL    = 1;
    PENABLE = 0;

    @(posedge PCLK);
    PENABLE = 1;

    @(posedge PCLK);
    PSEL    = 0;
    PENABLE = 0;
    PWRITE  = 0;
end
endtask

// ---------------------------------
// APB READ
// ---------------------------------
task apb_read;
input  [31:0] addr;
output [31:0] data;
begin
    @(posedge PCLK);
    PADDR   = addr;
    PWRITE  = 0;
    PSEL    = 1;
    PENABLE = 0;

    @(posedge PCLK);
    PENABLE = 1;

    #1;
    data = PRDATA;

    @(posedge PCLK);
    PSEL    = 0;
    PENABLE = 0;
end
endtask

// ---------------------------------
// VARIABLES
// ---------------------------------
reg [31:0] status;
reg [31:0] out_low, out_high;
reg [31:0] tag0, tag1, tag2, tag3;

reg [63:0] ct_ref;
reg [127:0] tag_ref;

integer timeout;

// ---------------------------------
// ENCRYPTION TASK
// ---------------------------------
task run_encryption;
begin
    // KEY
    apb_write(32'h18, 32'h0C0D0E0F);
    apb_write(32'h1C, 32'h08090A0B);
    apb_write(32'h20, 32'h04050607);
    apb_write(32'h24, 32'h00010203);

    // NONCE
    apb_write(32'h28, 32'h0C0D0E0F);
    apb_write(32'h2C, 32'h08090A0B);
    apb_write(32'h30, 32'h04050607);
    apb_write(32'h34, 32'h00010203);

    // PLAINTEXT
    apb_write(32'h08, 32'h00001111);
    apb_write(32'h0C, 32'h11110000);

    // START (encrypt mode = bit0=1)
    apb_write(32'h00, 32'h1);
    apb_write(32'h00, 32'h0);

    // WAIT FOR DONE
    timeout = 0;
    apb_read(32'h04, status);

    while(status[0] == 0 && timeout < 1000) begin
        #10;
        apb_read(32'h04, status);
        timeout = timeout + 1;
    end

    if(timeout == 1000) begin
        $display("ENCRYPT TIMEOUT");
        $finish;
    end

    #20;

    // READ CIPHERTEXT
    apb_read(32'h10, out_low);
    apb_read(32'h14, out_high);

    // READ TAG
    apb_read(32'h38, tag0);
    apb_read(32'h3C, tag1);
    apb_read(32'h40, tag2);
    apb_read(32'h44, tag3);
end
endtask

// ---------------------------------
// DECRYPTION TASK
// ---------------------------------
task run_decryption;
begin
    // KEY
    apb_write(32'h18, 32'h0C0D0E0F);
    apb_write(32'h1C, 32'h08090A0B);
    apb_write(32'h20, 32'h04050607);
    apb_write(32'h24, 32'h00010203);

    // NONCE
    apb_write(32'h28, 32'h0C0D0E0F);
    apb_write(32'h2C, 32'h08090A0B);
    apb_write(32'h30, 32'h04050607);
    apb_write(32'h34, 32'h00010203);

    // CIPHERTEXT INPUT
    apb_write(32'h08, ct_ref[31:0]);
    apb_write(32'h0C, ct_ref[63:32]);

    // WRITE RECEIVED TAG
    apb_write(32'h48, tag_ref[31:0]);
    apb_write(32'h4C, tag_ref[63:32]);
    apb_write(32'h50, tag_ref[95:64]);
    apb_write(32'h54, tag_ref[127:96]);

    // START (decrypt mode = bit1=1 + start)
    apb_write(32'h00, 32'h3);
    apb_write(32'h00, 32'h2);

    // WAIT FOR DONE
    timeout = 0;
    apb_read(32'h04, status);

    while(status[0] == 0 && timeout < 1000) begin
        #10;
        apb_read(32'h04, status);
        timeout = timeout + 1;
    end

    if(timeout == 1000) begin
        $display("DECRYPT TIMEOUT");
        $finish;
    end

    #20;

    // READ RECOVERED PLAINTEXT
    apb_read(32'h10, out_low);
    apb_read(32'h14, out_high);
end
endtask

// ---------------------------------
// TEST SEQUENCE
// ---------------------------------
initial begin

    // INIT
    PCLK = 0;
    PRESETn = 0;
    PADDR = 0;
    PSEL = 0;
    PENABLE = 0;
    PWRITE = 0;
    PWDATA = 0;

    #20;
    PRESETn = 1;

    $display("\n===== DECRYPT ONLY TEST =====");

    // -----------------------------------------
    // Load KEY
    // -----------------------------------------
    apb_write(32'h18, 32'h0C0D0E0F);
    apb_write(32'h1C, 32'h08090A0B);
    apb_write(32'h20, 32'h04050607);
    apb_write(32'h24, 32'h00010203);

    // -----------------------------------------
    // Load NONCE
    // -----------------------------------------
    apb_write(32'h28, 32'h0C0D0E0F);
    apb_write(32'h2C, 32'h08090A0B);
    apb_write(32'h30, 32'h04050607);
    apb_write(32'h34, 32'h00010203);

    // -----------------------------------------
    // Provide Ciphertext (from your previous run)
    // -----------------------------------------
    apb_write(32'h08, 32'hf3a1740a);
    apb_write(32'h0C, 32'had920fbe);

    // -----------------------------------------
    // Provide Tag (from your encryption result)
    // -----------------------------------------
    apb_write(32'h48, 32'hf4bb8c3e);
    apb_write(32'h4C, 32'hcaa4db86);
    apb_write(32'h50, 32'h9c9a14a3);
    apb_write(32'h54, 32'h52d70172);

    // -----------------------------------------
    // Force DECRYPT MODE
    // control_reg[1]=1 (decrypt)
    // control_reg[0]=1 (start)
    // -----------------------------------------
    apb_write(32'h00, 32'h3);

    // clear start but keep decrypt=1
    apb_write(32'h00, 32'h2);

    // -----------------------------------------
    // WAIT FOR DONE
    // -----------------------------------------
    timeout = 0;
    apb_read(32'h04, status);

    while(status[0] == 0 && timeout < 1000) begin
        #10;
        apb_read(32'h04, status);
        timeout = timeout + 1;
    end

    if(timeout == 1000) begin
        $display("DECRYPT TIMEOUT");
        $finish;
    end

    #20;

    // -----------------------------------------
    // Read plaintext
    // -----------------------------------------
    apb_read(32'h10, out_low);
    apb_read(32'h14, out_high);

    $display("\nRecovered PT = %h", {out_high, out_low});
    $display("Tag Valid    = %0d", status[2]);

    $display("\n===== END =====");

    #50;
    $finish;

end
endmodule
