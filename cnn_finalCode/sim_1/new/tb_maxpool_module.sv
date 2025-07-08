`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 29.06.2025 02:45:12
// Design Name: 
// Module Name: tb_maxpool_module
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


module tb_maxpool_module;

    localparam BIT_WIDTH       = 16;
    localparam FEAT_PIX_WIDTH  = 6; 
    localparam FEAT_RAM_DEPTH  = 6;
    localparam MAX_POOL_SIZE   = 2;
    localparam MAX_POOL_STRIDE = 2;

    localparam MAXP_PIX_WIDTH = ((FEAT_PIX_WIDTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;
    localparam MAXP_RAM_DEPTH = ((FEAT_RAM_DEPTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;

    // Clock and Reset
    logic clk, rst;
    logic maxp_module_enable;
    logic next_batch;

    // Input feature memory
    logic signed [BIT_WIDTH-1:0] feat_mem [0:FEAT_PIX_WIDTH-1][0:FEAT_RAM_DEPTH-1];
    logic signed [BIT_WIDTH-1:0] feat_re_data_in_row [0:FEAT_PIX_WIDTH-1];

    // DUT outputs
    logic [$clog2(FEAT_RAM_DEPTH)-1:0] feat_col_re_addr_row [0:FEAT_PIX_WIDTH-1];
    logic signed [BIT_WIDTH-1:0] maxp_data_out_row [0:MAXP_PIX_WIDTH-1];
    logic signed [$clog2(MAXP_RAM_DEPTH)-1:0] maxp_col_wr_addr_row [0:MAXP_PIX_WIDTH-1];
    logic data_ready_o;
    logic maxp_done;

    // DUT instantiation
    maxpool_module #(
        .BIT_WIDTH(BIT_WIDTH),
        .FEAT_PIX_WIDTH(FEAT_PIX_WIDTH),
        .FEAT_RAM_DEPTH(FEAT_RAM_DEPTH),
        .MAX_POOL_SIZE(MAX_POOL_SIZE),
        .MAX_POOL_STRIDE(MAX_POOL_STRIDE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .maxp_module_enable(maxp_module_enable),
        .next_batch(next_batch),
        .feat_re_data_in_row(feat_re_data_in_row),
        .feat_col_re_addr_row(feat_col_re_addr_row),
        .maxp_data_out_row(maxp_data_out_row),
        .maxp_col_wr_addr_row(maxp_col_wr_addr_row),
        .data_ready_o(data_ready_o),
        .maxp_done(maxp_done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin
        rst = 1;
        maxp_module_enable = 0;
        next_batch = 0;
        #20;
        rst = 0;

        // Initialize feature memory with sample values
        for (int i = 0; i < FEAT_PIX_WIDTH; i++) begin
            for (int j = 0; j < FEAT_RAM_DEPTH; j++) begin
                feat_mem[i][j] = (i + j) * 2;  // simple gradient values
            end
        end

        #10;
        maxp_module_enable = 1;

        wait(maxp_done);  // wait for pooling to complete

        #20;
        next_batch = 1;
        #10;
        next_batch = 0;

        $display("Maxpooling Outputs:");
        for (int i = 0; i < MAXP_PIX_WIDTH; i++) begin
            $display("maxp_data_out_row[%0d] = %0d, write_addr = %0d", i, maxp_data_out_row[i], maxp_col_wr_addr_row[i]);
        end

        #50;
        $finish;
    end

    // Drive inputs dynamically based on address
    always_ff @(posedge clk) begin
        for (int i = 0; i < FEAT_PIX_WIDTH; i++) begin
            feat_re_data_in_row[i] <= feat_mem[i][feat_col_re_addr_row[i]];
        end
    end

endmodule

