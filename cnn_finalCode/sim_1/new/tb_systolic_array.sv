`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 25.06.2025 22:58:35
// Design Name: 
// Module Name: tb_systolic_array
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

module tb_systolic_array;
    // Parameters matching DUT, intended to test systolic array's modularity.
    localparam BIT_WIDTH      = 16;
    localparam SA_PIXEL_WIDTH = 6;//5
    localparam KERNEL_SIZE    = 3;
    localparam CONV_RAM_DEPTH = 6;//64
    localparam KERN_RAM_DEPTH = 3;
    localparam FEAT_RAM_DEPTH = CONV_RAM_DEPTH - KERN_RAM_DEPTH + 1;//62
    localparam FEATURE_SIZE   = SA_PIXEL_WIDTH - KERNEL_SIZE + 1;

    // Clock & reset
    logic clk;
    logic rst;
    logic next_batch;
    logic sa_freeze;

    // DUT interface signals
    logic signed [BIT_WIDTH-1:0] pixel_rows_i   [0:SA_PIXEL_WIDTH-1];
    logic [$clog2(CONV_RAM_DEPTH)-1:0] re_addr_pixel_row  [0:SA_PIXEL_WIDTH-1];

    logic signed [BIT_WIDTH-1:0] kernel_rows_i  [0:KERNEL_SIZE-1];
    logic [$clog2(KERN_RAM_DEPTH)-1:0] re_addr_kernel_row  [0:KERNEL_SIZE-1];

    // DUT output
    logic signed [BIT_WIDTH-1:0] feature_rows_o [0:FEATURE_SIZE-1];
    logic [$clog2(FEAT_RAM_DEPTH)-1:0]  wr_addr_feat_row  [0:FEATURE_SIZE-1];

    logic feat_mem_ready;
    logic conv_done;

    // Instantiate DUT
    systolic_array #(
        .BIT_WIDTH(BIT_WIDTH),
        .SA_PIXEL_WIDTH(SA_PIXEL_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .PIX_RAM_DEPTH(CONV_RAM_DEPTH),
        .KERN_RAM_DEPTH(KERN_RAM_DEPTH),
        .FEAT_RAM_DEPTH(FEAT_RAM_DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .next_batch(next_batch),
        .sa_freeze(sa_freeze),
        .pixel_rows_i(pixel_rows_i),
        .re_addr_pixel_row(re_addr_pixel_row),
        .kernel_rows_i(kernel_rows_i),
        .re_addr_kernel_row(re_addr_kernel_row),
        .feature_rows_o(feature_rows_o),
        .wr_addr_feat_row(wr_addr_feat_row),
        .feat_mem_ready(feat_mem_ready),
        .conv_done(conv_done)
    );

    // Test memories: 5x3 pixel input and 3x3 kernel
    logic signed [BIT_WIDTH-1:0] pixel_mem [0:SA_PIXEL_WIDTH-1][0:CONV_RAM_DEPTH-1];
    logic signed [BIT_WIDTH-1:0] kernel_mem[0:KERN_RAM_DEPTH-1][0:KERN_RAM_DEPTH-1];


    // Initialize memories with 16-bit Q0.15 fixed-point values
    initial begin

        pixel_mem[0] = '{16'h7fff, 16'h7ff7, 16'h7ff8,16'h0000,16'h0000,16'h0000}; 
        pixel_mem[1] = '{16'h7fff, 16'h7ff7, 16'h7ff8,16'h0000,16'h0000,16'h0000}; 
        pixel_mem[2] = '{16'h7fff, 16'h7ff7, 16'h7ff8,16'h0000,16'h0000,16'h0000}; 
        pixel_mem[3] = '{16'h7fff, 16'h7ff7, 16'h7ff8,16'h0000,16'h0000,16'h0000}; 
        pixel_mem[4] = '{16'h7fff, 16'h7ff7, 16'h7ff8,16'h0000,16'h0000,16'h0000};
        pixel_mem[5] = '{16'h7fff, 16'h7ff7, 16'h7ff8,16'h0000,16'h0000,16'h0000};



        kernel_mem[0] = '{16'h0e39, 16'h0e39, 16'h0e39}; 
        kernel_mem[1] = '{16'h0e39, 16'h0e39, 16'h0e39}; 
        kernel_mem[2] = '{16'h0e39, 16'h0e39, 16'h0e39}; 
    end

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end



    // Reset  signals
    initial begin
        rst = 1;
        #20;
        rst = 0;
        #5;
        sa_freeze = 1;
        #20;
        sa_freeze = 0;
        #1150;
        next_batch = 1;
        #500;
        next_batch = 0;
        $finish;
    end

    // Drive DUT inputs each cycle based on read addresses
    always_ff @(posedge clk) begin

            for (int r = 0; r < SA_PIXEL_WIDTH; r++) begin
                pixel_rows_i[r] <= pixel_mem[r][ re_addr_pixel_row[r] ];
            end
            for (int k = 0; k < KERNEL_SIZE; k++) begin
                kernel_rows_i[k] <= kernel_mem[k][ re_addr_kernel_row[k] ];
            end

    end

endmodule



