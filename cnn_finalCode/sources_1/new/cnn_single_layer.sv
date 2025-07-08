`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 28.06.2025 18:55:15
// Design Name: 
// Module Name: cnn_single_layer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// Full single layer module , convolution-relu and maxpooling. with all required buffers for demo.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//note RelU is implemented in systolic array module - its inbuilt and optional - can be seen in line 348 of systolic_array.sv


module cnn_single_layer#(
    SA_PIXEL_WIDTH = 5,
    KERNEL_SIZE = 3,
    PIX_RAM_DEPTH = 64,
    BIT_WIDTH = 16,
    MAX_POOL_STRIDE = 2,
    MAX_POOL_SIZE   = 2
)(
    input clk,
    input rst,
    //write to pixel_buffer ports
    input logic                               wr_en_row_pix [0 : SA_PIXEL_WIDTH - 1],
    input logic [$clog2(PIX_RAM_DEPTH)-1:0]   wr_addr_row_pix [0 : SA_PIXEL_WIDTH - 1],
    input logic signed [BIT_WIDTH-1:0]        wr_data_row_pix [0 : SA_PIXEL_WIDTH - 1],
    input logic                               pix_buff_valid,

    //write to kernel_buffer ports
    input logic                               wr_en_row_kern [0 : KERNEL_SIZE - 1],
    input logic [$clog2(KERNEL_SIZE)-1:0]     wr_addr_row_kern [0 : KERNEL_SIZE - 1],
    input logic signed [BIT_WIDTH-1:0]        wr_data_row_kern [0 : KERNEL_SIZE - 1],
    input logic                               kern_buff_valid,

    input logic                               layer_data_read_enable,
    input logic [$clog2(((((PIX_RAM_DEPTH - KERNEL_SIZE + 1)) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1:0]                             layer_data_read_addr[0:((((SA_PIXEL_WIDTH - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1],
    output logic signed [BIT_WIDTH-1:0]       layer_data_out[0:((((SA_PIXEL_WIDTH - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1],
    output logic                              layer_done
    );
    localparam KERN_RAM_DEPTH = KERNEL_SIZE;

    //wires for pixel_buffer
    logic                               re_en_row_pix [0 : SA_PIXEL_WIDTH - 1];

    //wires for kernel_buffer
    logic                               re_en_row_kern [0 : KERNEL_SIZE - 1];

    localparam FEAT_RAM_DEPTH = PIX_RAM_DEPTH - KERN_RAM_DEPTH + 1;
    localparam FEAT_PIX_WIDTH = SA_PIXEL_WIDTH - KERNEL_SIZE + 1;

    //wires for systolic array
    logic                               next_batch;
    logic signed [BIT_WIDTH-1:0]        pixel_rows_i        [0:SA_PIXEL_WIDTH-1];
    logic [$clog2(PIX_RAM_DEPTH)-1:0]   re_addr_pixel_row   [0:SA_PIXEL_WIDTH-1];

    logic signed [BIT_WIDTH-1:0]        kernel_rows_i       [0:KERNEL_SIZE-1];
    logic [$clog2(KERN_RAM_DEPTH)-1:0]  re_addr_kernel_row  [0:KERNEL_SIZE-1];
    logic signed [BIT_WIDTH-1:0]        feature_rows_o      [0:SA_PIXEL_WIDTH-KERNEL_SIZE];
    logic [$clog2(FEAT_RAM_DEPTH)-1:0]  wr_addr_feat_row    [0:SA_PIXEL_WIDTH-KERNEL_SIZE];
    logic                               feat_mem_ready;
    logic                               sa_freeze;
    logic                               conv_done;
    //wires for feature_buffer

    logic                               wr_en_row_feat [0 : FEAT_PIX_WIDTH - 1];
    logic                               re_en_row_feat [0 : FEAT_PIX_WIDTH - 1];
    logic [$clog2(FEAT_RAM_DEPTH)-1:0]  re_addr_row_feat [0 : FEAT_PIX_WIDTH - 1];
    logic signed [BIT_WIDTH-1:0]        re_data_row_feat [0 : FEAT_PIX_WIDTH - 1];

    genvar i;
    //logic to enable read ports and unfreeze systolic array:
    generate
        for (i = 0 ; i < SA_PIXEL_WIDTH ; i++ ) begin
            assign re_en_row_pix[i] = (pix_buff_valid && kern_buff_valid) ? 1 : 0; 
        end
        for (i = 0 ; i < KERNEL_SIZE ; i++ ) begin
            assign re_en_row_kern[i] = (pix_buff_valid && kern_buff_valid) ? 1 : 0; 
        end
    endgenerate

    assign sa_freeze = (pix_buff_valid && kern_buff_valid) ? 0 : 1;

    //logic to connect enable signal from systolic array :
    generate
        for (i = 0 ; i < FEAT_PIX_WIDTH ; i++ ) begin
            assign wr_en_row_feat[i] = feat_mem_ready ? 1 : 0;
        end
    endgenerate

    //wires for maxpooling
    localparam MAXP_PIX_WIDTH = ((FEAT_PIX_WIDTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;
    localparam MAXP_RAM_DEPTH = ((FEAT_RAM_DEPTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;

    logic signed [BIT_WIDTH-1:0] maxp_data_out_row [0:(MAXP_PIX_WIDTH)-1];
    logic [$clog2(MAXP_RAM_DEPTH)-1:0] maxp_col_wr_addr_row [0:(MAXP_PIX_WIDTH)-1];
    logic maxp_data_ready;
    logic maxp_enable;
    logic maxp_mem_wr_en [0:MAXP_PIX_WIDTH-1];
    logic layer_data_read_enable_mod [0:MAXP_PIX_WIDTH-1];

    //logic to connect finish signal from systolic array :
    assign maxp_enable = conv_done ? 1 :0 ;
    generate
        for (i = 0 ; i < FEAT_PIX_WIDTH ; i++ ) begin
            assign re_en_row_feat[i] = conv_done ? 1 : 0;
        end
    endgenerate

    generate
        for (i = 0 ; i < MAXP_PIX_WIDTH ; i++ ) begin
            assign maxp_mem_wr_en[i] = maxp_data_ready ? 1 : 0;
        end
    endgenerate

    generate
        for (i = 0 ; i < MAXP_PIX_WIDTH ; i++ ) begin
            assign layer_data_read_enable_mod[i] = layer_data_read_enable ? 1 : 0;
        end
    endgenerate


    assign next_batch = 0; // for the current purpose , single image. provision given for future pipelining or tiling images.
    //use next_batches for sa and maxpooling individually , so create them as necessary.

    array_buffer_memory #(
        .NUM_LBUFS(SA_PIXEL_WIDTH),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(PIX_RAM_DEPTH)
    )pix_buff_mem_in(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(wr_en_row_pix),
        .re_en_row(re_en_row_pix),
        .wr_addr_row(wr_addr_row_pix),
        .re_addr_row(re_addr_pixel_row),
        .wr_data_row(wr_data_row_pix),
        .re_data_row(pixel_rows_i)
    );

    array_buffer_memory #(
        .NUM_LBUFS(KERNEL_SIZE),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(KERN_RAM_DEPTH)
    )kern_buff_mem_in(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(wr_en_row_kern),
        .re_en_row(re_en_row_kern),
        .wr_addr_row(wr_addr_row_kern),
        .re_addr_row(re_addr_kernel_row),
        .wr_data_row(wr_data_row_kern),
        .re_data_row(kernel_rows_i)
    );


    systolic_array #(
        .BIT_WIDTH(BIT_WIDTH),
        .SA_PIXEL_WIDTH(SA_PIXEL_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .PIX_RAM_DEPTH(PIX_RAM_DEPTH),
        .KERN_RAM_DEPTH(KERN_RAM_DEPTH),
        .FEAT_RAM_DEPTH(FEAT_RAM_DEPTH)
    )systolic_array_inst(
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

    array_buffer_memory #(
        .NUM_LBUFS(FEAT_PIX_WIDTH),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(FEAT_RAM_DEPTH)
    )feat_buff_mem(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(wr_en_row_feat),
        .re_en_row(re_en_row_feat),
        .wr_addr_row(wr_addr_feat_row),
        .re_addr_row(re_addr_row_feat),
        .wr_data_row(feature_rows_o),
        .re_data_row(re_data_row_feat)
    );


    maxpool_module #(
        .BIT_WIDTH(BIT_WIDTH),
        .FEAT_PIX_WIDTH(FEAT_PIX_WIDTH),
        .FEAT_RAM_DEPTH(FEAT_RAM_DEPTH),
        .MAX_POOL_SIZE(MAX_POOL_SIZE),
        .MAX_POOL_STRIDE(MAX_POOL_STRIDE)
    )maxp_module_inst(
        .clk(clk),
        .rst(rst),
        .maxp_module_enable(maxp_enable),
        .next_batch(next_batch),
        .feat_re_data_in_row(re_data_row_feat),
        .feat_col_re_addr_row(re_addr_row_feat),
        .maxp_data_out_row(maxp_data_out_row),
        .maxp_col_wr_addr_row(maxp_col_wr_addr_row),
        .data_ready_o(maxp_data_ready),
        .maxp_done(layer_done)
    );
    array_buffer_memory #(
        .NUM_LBUFS(MAXP_PIX_WIDTH),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(MAXP_RAM_DEPTH)
    )maxp_buffer_mem(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(maxp_mem_wr_en),
        .re_en_row(layer_data_read_enable_mod),
        .wr_addr_row(maxp_col_wr_addr_row),
        .re_addr_row(layer_data_read_addr),
        .wr_data_row(maxp_data_out_row),
        .re_data_row(layer_data_out)
    );

endmodule
