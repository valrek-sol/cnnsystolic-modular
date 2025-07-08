`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 01.07.2025 16:20:52
// Design Name: 
// Module Name: cnn_layer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// Layer containing Convolution-relu  and feature buffer and maxpooling only. for scalability/modularity.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//note RelU is implemented in systolic array module - its inbuilt and optional - can be seen in line 348 of systolic_array.sv

module cnn_layer#(
    SA_PIXEL_WIDTH = 5,
    KERNEL_SIZE = 3,
    PIX_RAM_DEPTH = 64,
    BIT_WIDTH = 16,
    MAX_POOL_STRIDE = 2,
    MAX_POOL_SIZE   = 2
)(
    input clk,
    input rst,

    //read from outside - image pixels/maxpool result from previous layer
    output logic read_enable_pix [0:SA_PIXEL_WIDTH-1],
    output logic [$clog2(PIX_RAM_DEPTH)-1:0]read_address_pix [0:SA_PIXEL_WIDTH-1],
    input  logic signed [BIT_WIDTH-1:0] read_data_pix   [0:SA_PIXEL_WIDTH-1],
    input  logic pix_data_in_valid_in, //asserted only once external buffer is fully ready

    //read kernel from outside
    output  logic                            read_enable_kern   [0:KERNEL_SIZE-1],
    output  logic    [$clog2(KERNEL_SIZE)-1:0] read_address_kern  [0:KERNEL_SIZE-1],
    input   logic    signed [BIT_WIDTH-1:0]  read_data_kern     [0:KERNEL_SIZE-1],
    input   logic                            kern_data_in_valid_in, //asserted only once external buffer is fully ready

    //output maxpooled data to outside memory
    output logic [$clog2((((PIX_RAM_DEPTH-KERNEL_SIZE+1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1:0]write_address_maxp [0:((((SA_PIXEL_WIDTH - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1],
    output logic signed [BIT_WIDTH-1:0] write_data_maxp [0:((((SA_PIXEL_WIDTH - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1],
    output logic maxp_data_out_valid_out, //asserted everytime data is ready
    output logic layer_done //asserted when all outputs are completed
    );

    localparam KERN_RAM_DEPTH = KERNEL_SIZE;
    localparam FEAT_RAM_DEPTH = PIX_RAM_DEPTH - KERN_RAM_DEPTH + 1;
    localparam FEAT_PIX_WIDTH = SA_PIXEL_WIDTH - KERNEL_SIZE + 1;
    localparam MAXP_PIX_WIDTH = ((FEAT_PIX_WIDTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;
    localparam MAXP_RAM_DEPTH = ((FEAT_RAM_DEPTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;
    genvar i;

    //wires and logic for systolic array

    logic next_batch;
    assign next_batch = 0;// for the current purpose , single image. provision given for future pipelining or tiling images.
    //use next_batches for sa and maxpooling individually , so create them as necessary.
    logic sa_freeze;
    logic conv_done;
    assign sa_freeze = (pix_data_in_valid_in && kern_data_in_valid_in) ? 0 : 1;
    logic signed [BIT_WIDTH-1:0]        feature_data_out_sa      [0:FEAT_PIX_WIDTH-1];
    logic [$clog2(FEAT_RAM_DEPTH)-1:0]  wr_addr_feat_row    [0:FEAT_PIX_WIDTH-1];
    logic                               feat_mem_ready;
    generate
        for (i = 0;i < SA_PIXEL_WIDTH; i++ ) begin
            assign read_enable_pix[i] = pix_data_in_valid_in ? 1 : 0;
        end
    endgenerate
    generate
        for (i = 0;i < KERNEL_SIZE; i++ ) begin
            assign read_enable_kern[i] = kern_data_in_valid_in ? 1 : 0;
        end
    endgenerate
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
        .pixel_rows_i(read_data_pix),
        .re_addr_pixel_row(read_address_pix),
        .kernel_rows_i(read_data_kern),
        .re_addr_kernel_row(read_address_kern),
        .feature_rows_o(feature_data_out_sa),
        .wr_addr_feat_row(wr_addr_feat_row),
        .feat_mem_ready(feat_mem_ready),
        .conv_done(conv_done)
    );

    //wires and logic for feature buffer memory
    logic                               wr_en_row_feat [0 : FEAT_PIX_WIDTH - 1];
    logic                               re_en_row_feat [0 : FEAT_PIX_WIDTH - 1];
    logic [$clog2(FEAT_RAM_DEPTH)-1:0]  re_addr_row_feat [0 : FEAT_PIX_WIDTH - 1];
    logic signed [BIT_WIDTH-1:0]        re_data_row_feat [0 : FEAT_PIX_WIDTH - 1];

    //logic to connect enable signal from systolic array :
    generate
        for (i = 0 ; i < FEAT_PIX_WIDTH ; i++ ) begin
            assign wr_en_row_feat[i] = feat_mem_ready ? 1 : 0;
        end
    endgenerate

    //wires and logic for maxpooler
    logic maxp_enable;

    //logic to connect finish signal from systolic array :
    assign maxp_enable = conv_done ? 1 :0 ;
    generate
        for (i = 0 ; i < FEAT_PIX_WIDTH ; i++ ) begin
            assign re_en_row_feat[i] = conv_done ? 1 : 0;
        end
    endgenerate


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
        .wr_data_row(feature_data_out_sa),
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
        .maxp_data_out_row(write_data_maxp),
        .maxp_col_wr_addr_row(write_address_maxp),
        .data_ready_o(maxp_data_out_valid_out),
        .maxp_done(layer_done)
    );


endmodule
