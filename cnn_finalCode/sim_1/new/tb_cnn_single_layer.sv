`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan 
// 
// Create Date: 29.06.2025 01:27:34
// Design Name: 
// Module Name: tb_cnn_single_layer
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
// note : in simulator , adjust simulation duration setting, 1000ns is not sufficient, set around 37,000ns or above.
module tb_cnn_single_layer;

    localparam SA_PIXEL_WIDTH = 12;
    localparam KERNEL_SIZE = 3;
    localparam PIX_RAM_DEPTH = 12;
    localparam BIT_WIDTH = 16;
    localparam MAX_POOL_STRIDE = 2;
    localparam MAX_POOL_SIZE = 2;

    localparam FEAT_PIX_WIDTH = SA_PIXEL_WIDTH - KERNEL_SIZE + 1;
    localparam FEAT_RAM_DEPTH = PIX_RAM_DEPTH - KERNEL_SIZE + 1;

    localparam MAXP_PIX_WIDTH = ((FEAT_PIX_WIDTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;
    localparam MAXP_RAM_DEPTH = ((FEAT_RAM_DEPTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;

    logic clk;
    logic rst;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Inputs to cnn_layer1
    logic                               wr_en_row_pix     [0 : SA_PIXEL_WIDTH - 1];
    logic [$clog2(PIX_RAM_DEPTH)-1:0]   wr_addr_row_pix   [0 : SA_PIXEL_WIDTH - 1];
    logic signed [BIT_WIDTH-1:0]        wr_data_row_pix   [0 : SA_PIXEL_WIDTH - 1];
    logic                               pix_buff_valid;

    logic                               wr_en_row_kern    [0 : KERNEL_SIZE - 1];
    logic [$clog2(KERNEL_SIZE)-1:0]     wr_addr_row_kern  [0 : KERNEL_SIZE - 1];
    logic signed [BIT_WIDTH-1:0]        wr_data_row_kern  [0 : KERNEL_SIZE - 1];
    logic                               kern_buff_valid;

    logic                               layer1_data_read_enable;
    logic [$clog2(MAXP_RAM_DEPTH)-1:0]  layer1_data_out_addr[0 : MAXP_PIX_WIDTH - 1];
    logic signed [BIT_WIDTH-1:0]        layer1_data_out[0 : MAXP_PIX_WIDTH - 1];
    logic                               layer_done;

    // DUT instantiation
    cnn_single_layer #(
        .SA_PIXEL_WIDTH(SA_PIXEL_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .PIX_RAM_DEPTH(PIX_RAM_DEPTH),
        .BIT_WIDTH(BIT_WIDTH),
        .MAX_POOL_STRIDE(MAX_POOL_STRIDE),
        .MAX_POOL_SIZE(MAX_POOL_SIZE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en_row_pix(wr_en_row_pix),
        .wr_addr_row_pix(wr_addr_row_pix),
        .wr_data_row_pix(wr_data_row_pix),
        .pix_buff_valid(pix_buff_valid),
        .wr_en_row_kern(wr_en_row_kern),
        .wr_addr_row_kern(wr_addr_row_kern),
        .wr_data_row_kern(wr_data_row_kern),
        .kern_buff_valid(kern_buff_valid),
        .layer_data_read_enable(layer1_data_read_enable),
        .layer_data_read_addr(layer1_data_out_addr),
        .layer_data_out(layer1_data_out),
        .layer_done(layer_done)
    );

    // Internal control logic
    initial begin
        rst = 1;
        pix_buff_valid = 0;
        kern_buff_valid = 0;
        layer1_data_read_enable = 0;

        foreach (wr_en_row_pix[i]) begin
            wr_en_row_pix[i] = 0;
            wr_addr_row_pix[i] = 0;
            wr_data_row_pix[i] = 0;
        end

        foreach (wr_en_row_kern[i]) begin
            wr_en_row_kern[i] = 0;
            wr_addr_row_kern[i] = 0;
            wr_data_row_kern[i] = 0;
        end

        #20;
        rst = 0;

        // === KERNEL LOAD ===
        for (int addr = 0; addr < KERNEL_SIZE; addr++) begin
            @(posedge clk);
            for (int k = 0; k < KERNEL_SIZE; k++) begin
                wr_en_row_kern[k] = 1;
                wr_addr_row_kern[k] = addr;
                wr_data_row_kern[k] = 16'h0339; // 0.1
            end
        end
        @(posedge clk);
        foreach (wr_en_row_kern[k]) wr_en_row_kern[k] = 0;
        kern_buff_valid = 1;

        // === PIXEL LOAD ===
        for (int addr = 0; addr < PIX_RAM_DEPTH; addr++) begin
            @(posedge clk);
            for (int p = 0; p < SA_PIXEL_WIDTH; p++) begin
                wr_en_row_pix[p] = 1;
                wr_addr_row_pix[p] = addr;
                wr_data_row_pix[p] = 16'h0037 *(addr + p); 
            end
        end
        @(posedge clk);
        foreach (wr_en_row_pix[p]) wr_en_row_pix[p] = 0;
        pix_buff_valid = 1;

        // Wait for convolution + maxpooling
        wait (layer_done);
        $display("Convolution + MaxPooling finished.");

        @(posedge clk);

        // === READ OUT ===
        layer1_data_read_enable = 1;
        for (int addr = 0; addr < MAXP_RAM_DEPTH; addr++) begin
            @(posedge clk);
            for (int i = 0; i < MAXP_PIX_WIDTH; i++) begin
                layer1_data_out_addr[i] = addr;
            end

            @(posedge clk);
            $write("Output Row[%0d]: ", addr);
            for (int i = 0; i < MAXP_PIX_WIDTH; i++) begin
                $write("%0d ", layer1_data_out[i]);
            end
            $write("\n");
        end

        @(posedge clk);
        layer1_data_read_enable = 0;

        #20;
        $display("Simulation completed.");
        $finish;
    end

endmodule

