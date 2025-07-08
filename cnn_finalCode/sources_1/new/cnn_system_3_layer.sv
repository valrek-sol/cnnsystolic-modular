`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 30.06.2025 23:26:36
// Design Name: 
// Module Name: cnn_system_3_layer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// A 3 layer demo of the cnn using all relevant modules.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//note RelU is implemented in systolic array module - its inbuilt and optional - can be seen in line 348 of systolic_array.sv

// 32 is the best minimum value to demo 3 layers of cnn with maxpooling every layer..
module cnn_system_3_layer#(
    IMG_HEIGHT = 32,
    KERNEL_SIZE = 3,
    IMG_WIDTH  = 32,
    BIT_WIDTH  = 16,
    MAX_POOL_SIZE = 2,
    MAX_POOL_STRIDE  = 2
)(
    input clk,
    input rst,
    input logic wr_en_img_row [0:IMG_HEIGHT-1],
    input logic [$clog2(IMG_WIDTH)-1:0] wr_addr_img_row [0:IMG_HEIGHT-1],
    input logic signed [BIT_WIDTH-1:0] wr_data_img_row  [0:IMG_HEIGHT-1],
    input logic                         img_buff_valid,

    input logic wr_en_kern_row [0:KERNEL_SIZE-1],
    input logic [$clog2(KERNEL_SIZE)-1:0] wr_addr_kern_row [0:KERNEL_SIZE-1],
    input logic signed [BIT_WIDTH-1:0] wr_data_kern_row  [0:KERNEL_SIZE-1],
    input logic                         kern_buff_valid,

    //L3_MAXP_RAM_DEPTH
    input logic [$clog2(((((((((((((((IMG_WIDTH - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)) - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)) - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1))-1:0]  layers_data_read_addr   [0:(((((((((( (((((IMG_HEIGHT - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)) - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1))) - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1],

    output logic signed [BIT_WIDTH-1:0] layers_data_out [0:(((((((((( (((((IMG_HEIGHT - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)) - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1))) - KERNEL_SIZE + 1) - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1], //L3_MAXP_PIX_WIDTH 
    output logic                        layers_done
    );

    localparam KERN_RAM_DEPTH = KERNEL_SIZE;
    //common
    logic re_en_row_kernl1  [0:KERNEL_SIZE-1];
    logic re_en_row_kernl2  [0:KERNEL_SIZE-1];
    logic re_en_row_kernl3  [0:KERNEL_SIZE-1];

    logic [$clog2(KERN_RAM_DEPTH)-1:0] re_addr_kern_rowl1 [0:KERNEL_SIZE-1];
    logic [$clog2(KERN_RAM_DEPTH)-1:0] re_addr_kern_rowl2 [0:KERNEL_SIZE-1];
    logic [$clog2(KERN_RAM_DEPTH)-1:0] re_addr_kern_rowl3 [0:KERNEL_SIZE-1];

    logic signed [BIT_WIDTH-1:0] read_data_kern_rowl1 [0:KERNEL_SIZE-1];
    logic signed [BIT_WIDTH-1:0] read_data_kern_rowl2 [0:KERNEL_SIZE-1];
    logic signed [BIT_WIDTH-1:0] read_data_kern_rowl3 [0:KERNEL_SIZE-1];
    //layer 1
    localparam L1_SA_PIXEL_WIDTH = IMG_HEIGHT;
    localparam L1_PIX_RAM_DEPTH  = IMG_WIDTH;

    localparam L1_FEAT_PIX_WIDTH = L1_SA_PIXEL_WIDTH - KERNEL_SIZE + 1;
    localparam L1_FEAT_RAM_DEPTH = L1_PIX_RAM_DEPTH - KERN_RAM_DEPTH + 1;

    localparam L1_MAXP_PIX_WIDTH = ((L1_FEAT_PIX_WIDTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;
    localparam L1_MAXP_RAM_DEPTH = ((L1_FEAT_RAM_DEPTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;

    logic re_en_row_layer1 [0:L1_SA_PIXEL_WIDTH-1];
    logic [$clog2(L1_PIX_RAM_DEPTH)-1:0] re_addr_row_layer1 [0:L1_SA_PIXEL_WIDTH-1];
    logic signed [BIT_WIDTH-1:0] re_data_row_layer1 [0:L1_SA_PIXEL_WIDTH-1];

    logic layer1_done;

    genvar i;

    logic layer1_valid_data_o;
    logic wr_en_row_layer1 [L1_MAXP_PIX_WIDTH-1:0];
    generate
        for (i = 0;i < L1_MAXP_PIX_WIDTH ; i++ ) begin
            assign wr_en_row_layer1[i] = layer1_valid_data_o;
        end
    endgenerate

    logic [$clog2(L1_MAXP_RAM_DEPTH)-1:0] write_address_maxp_layer1 [L1_MAXP_PIX_WIDTH-1:0];
    logic signed [BIT_WIDTH-1:0] write_data_maxp_layer1 [L1_MAXP_PIX_WIDTH-1:0];


    //layer 2
    localparam L2_SA_PIXEL_WIDTH = L1_MAXP_PIX_WIDTH;
    localparam L2_PIX_RAM_DEPTH  = L1_MAXP_RAM_DEPTH;

    localparam L2_FEAT_PIX_WIDTH = L2_SA_PIXEL_WIDTH - KERNEL_SIZE + 1;
    localparam L2_FEAT_RAM_DEPTH = L2_PIX_RAM_DEPTH - KERN_RAM_DEPTH + 1;

    localparam L2_MAXP_PIX_WIDTH = ((L2_FEAT_PIX_WIDTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;
    localparam L2_MAXP_RAM_DEPTH = ((L2_FEAT_RAM_DEPTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;

    logic re_en_row_layer2 [0:L2_SA_PIXEL_WIDTH-1];
    logic [$clog2(L2_PIX_RAM_DEPTH)-1:0] re_addr_row_layer2 [0:L2_SA_PIXEL_WIDTH-1];
    logic signed [BIT_WIDTH-1:0] re_data_row_layer2 [0:L2_SA_PIXEL_WIDTH-1];
    logic layer2_done;

    logic layer2_valid_data_o;
    logic wr_en_row_layer2 [L2_MAXP_PIX_WIDTH-1:0];
    generate
        for (i = 0;i < L2_MAXP_PIX_WIDTH ; i++ ) begin
            assign wr_en_row_layer2[i] = layer2_valid_data_o;
        end
    endgenerate

    logic [$clog2(L2_MAXP_RAM_DEPTH)-1:0] write_address_maxp_layer2 [L2_MAXP_PIX_WIDTH-1:0];
    logic signed [BIT_WIDTH-1:0] write_data_maxp_layer2 [L2_MAXP_PIX_WIDTH-1:0];

    //layer 3
    localparam L3_SA_PIXEL_WIDTH = L2_MAXP_PIX_WIDTH;
    localparam L3_PIX_RAM_DEPTH  = L2_MAXP_RAM_DEPTH;

    localparam L3_FEAT_PIX_WIDTH = L3_SA_PIXEL_WIDTH - KERNEL_SIZE + 1;
    localparam L3_FEAT_RAM_DEPTH = L3_PIX_RAM_DEPTH - KERN_RAM_DEPTH + 1;

    localparam L3_MAXP_PIX_WIDTH = ((L3_FEAT_PIX_WIDTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;
    localparam L3_MAXP_RAM_DEPTH = ((L3_FEAT_RAM_DEPTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;

    logic re_en_row_layer3 [0:L3_SA_PIXEL_WIDTH-1];
    logic [$clog2(L3_PIX_RAM_DEPTH)-1:0] re_addr_row_layer3 [0:L3_SA_PIXEL_WIDTH-1];
    logic signed [BIT_WIDTH-1:0] re_data_row_layer3 [0:L3_SA_PIXEL_WIDTH-1];
    
    logic layer3_valid_data_o;
    logic wr_en_row_layer3 [L3_MAXP_PIX_WIDTH-1:0];
    generate
        for (i = 0;i < L3_MAXP_PIX_WIDTH ; i++ ) begin
            assign wr_en_row_layer3[i] = layer3_valid_data_o;
        end
    endgenerate

    logic [$clog2(L3_MAXP_RAM_DEPTH)-1:0] write_address_maxp_layer3 [L3_MAXP_PIX_WIDTH-1:0];
    logic signed [BIT_WIDTH-1:0] write_data_maxp_layer3 [L3_MAXP_PIX_WIDTH-1:0];

    logic re_en_row_last [L3_MAXP_PIX_WIDTH-1:0]; //default it to one, always read enabled.. modify according to use case
    generate
        for (i = 0; i < L3_MAXP_PIX_WIDTH ; i++ ) begin
            assign re_en_row_last[i] = 1;
        end
    endgenerate
    //instantiations and connections


    array_buffer_memory #(
        .NUM_LBUFS(L1_SA_PIXEL_WIDTH),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(L1_PIX_RAM_DEPTH)
    )pix_buff_mem_in(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(wr_en_img_row),       //<----input  
        .re_en_row(re_en_row_layer1),       //<----input
        .wr_addr_row(wr_addr_img_row),     //<----input
        .re_addr_row(re_addr_row_layer1),     //<----input
        .wr_data_row(wr_data_img_row),     //<----input
        .re_data_row(re_data_row_layer1)      //--->output
    );

    array_buffer_memory #(
        .NUM_LBUFS(KERNEL_SIZE),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(KERN_RAM_DEPTH)
    )kern_buff_mem_in1(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(wr_en_kern_row),       //<----input
        .re_en_row(re_en_row_kernl1 ),       //<----input
        .wr_addr_row(wr_addr_kern_row),     //<----input
        .re_addr_row(re_addr_kern_rowl1),     //<----input
        .wr_data_row(wr_data_kern_row),     //<----input
        .re_data_row(read_data_kern_rowl1)      //--->output
    );

    array_buffer_memory #(
        .NUM_LBUFS(KERNEL_SIZE),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(KERN_RAM_DEPTH)
    )kern_buff_mem_in2(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(wr_en_kern_row),       //<----input
        .re_en_row(re_en_row_kernl2 ),       //<----input
        .wr_addr_row(wr_addr_kern_row),     //<----input
        .re_addr_row(re_addr_kern_rowl2),     //<----input
        .wr_data_row(wr_data_kern_row),     //<----input
        .re_data_row(read_data_kern_rowl2)      //--->output
    );

    array_buffer_memory #(
        .NUM_LBUFS(KERNEL_SIZE),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(KERN_RAM_DEPTH)
    )kern_buff_mem_in3(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(wr_en_kern_row),       //<----input
        .re_en_row(re_en_row_kernl3 ),       //<----input
        .wr_addr_row(wr_addr_kern_row),     //<----input
        .re_addr_row(re_addr_kern_rowl3),     //<----input
        .wr_data_row(wr_data_kern_row),     //<----input
        .re_data_row(read_data_kern_rowl3)      //--->output
    );

    cnn_layer #(
        .SA_PIXEL_WIDTH(L1_SA_PIXEL_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .PIX_RAM_DEPTH(L1_PIX_RAM_DEPTH),
        .BIT_WIDTH(BIT_WIDTH),
        .MAX_POOL_STRIDE(MAX_POOL_STRIDE),
        .MAX_POOL_SIZE(MAX_POOL_SIZE)
    )cnn_layer1_inst(
        .clk(clk),
        .rst(rst),
        .read_enable_pix(re_en_row_layer1),         //--->output
        .read_address_pix(re_addr_row_layer1),        //--->output
        .read_data_pix(re_data_row_layer1),           //<----input
        .pix_data_in_valid_in(img_buff_valid),    //<----input
        .read_enable_kern(re_en_row_kernl1),        //--->output
        .read_address_kern(re_addr_kern_rowl1),       //--->output
        .read_data_kern(read_data_kern_rowl1),          //<----input
        .kern_data_in_valid_in(kern_buff_valid),   //<----input
        .write_address_maxp(write_address_maxp_layer1),      //--->output
        .write_data_maxp(write_data_maxp_layer1),         //--->output
        .maxp_data_out_valid_out(layer1_valid_data_o),       //--->output
        .layer_done(layer1_done)               //--->output
    );

    array_buffer_memory #(
        .NUM_LBUFS(L1_MAXP_PIX_WIDTH),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(L1_MAXP_RAM_DEPTH)
    )maxp_buffer_mem_layer1(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(wr_en_row_layer1),       //<----input
        .re_en_row(re_en_row_layer2),       //<----input
        .wr_addr_row(write_address_maxp_layer1),     //<----input
        .re_addr_row(re_addr_row_layer2),     //<----input
        .wr_data_row(write_data_maxp_layer1),     //<----input
        .re_data_row(re_data_row_layer2)      //--->output
    );

    cnn_layer #(
        .SA_PIXEL_WIDTH(L2_SA_PIXEL_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .PIX_RAM_DEPTH(L2_PIX_RAM_DEPTH),
        .BIT_WIDTH(BIT_WIDTH),
        .MAX_POOL_STRIDE(MAX_POOL_STRIDE),
        .MAX_POOL_SIZE(MAX_POOL_SIZE)
    )cnn_layer2_inst(
        .clk(clk),
        .rst(rst),
        .read_enable_pix(re_en_row_layer2),         //--->output
        .read_address_pix(re_addr_row_layer2),        //--->output
        .read_data_pix(re_data_row_layer2),           //<----input
        .pix_data_in_valid_in(layer1_done),    //<----input
        .read_enable_kern(re_en_row_kernl2),        //--->output
        .read_address_kern(re_addr_kern_rowl2),       //--->output
        .read_data_kern(read_data_kern_rowl2),          //<----input
        .kern_data_in_valid_in(kern_buff_valid),   //<----input
        .write_address_maxp(write_address_maxp_layer2),      //--->output
        .write_data_maxp(write_data_maxp_layer2),         //--->output
        .maxp_data_out_valid_out(layer2_valid_data_o),       //--->output
        .layer_done(layer2_done)               //--->output
    );

    array_buffer_memory #(
        .NUM_LBUFS(L2_MAXP_PIX_WIDTH),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(L2_MAXP_RAM_DEPTH)
    )maxp_buffer_mem_layer2(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(wr_en_row_layer2),       //<----input
        .re_en_row(re_en_row_layer3),       //<----input
        .wr_addr_row(write_address_maxp_layer2),     //<----input
        .re_addr_row(re_addr_row_layer3),     //<----input
        .wr_data_row(write_data_maxp_layer2),     //<----input
        .re_data_row(re_data_row_layer3)      //--->output
    );

    cnn_layer #(
        .SA_PIXEL_WIDTH(L3_SA_PIXEL_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .PIX_RAM_DEPTH(L3_PIX_RAM_DEPTH),
        .BIT_WIDTH(BIT_WIDTH),
        .MAX_POOL_STRIDE(MAX_POOL_STRIDE),
        .MAX_POOL_SIZE(MAX_POOL_SIZE)
    )cnn_layer3_inst(
        .clk(clk),
        .rst(rst),
        .read_enable_pix(re_en_row_layer3),         //--->output
        .read_address_pix(re_addr_row_layer3),        //--->output
        .read_data_pix(re_data_row_layer3),           //<----input
        .pix_data_in_valid_in(layer2_done),    //<----input
        .read_enable_kern(re_en_row_kernl3),        //--->output
        .read_address_kern(re_addr_kern_rowl3),       //--->output
        .read_data_kern(read_data_kern_rowl3),          //<----input
        .kern_data_in_valid_in(kern_buff_valid),   //<----input
        .write_address_maxp(write_address_maxp_layer3),      //--->output
        .write_data_maxp(write_data_maxp_layer3),         //--->output
        .maxp_data_out_valid_out(layer3_valid_data_o),       //--->output
        .layer_done(layers_done)               //--->output
    );


    array_buffer_memory #(
        .NUM_LBUFS(L3_MAXP_PIX_WIDTH),
        .BIT_WIDTH(BIT_WIDTH),
        .RAM_DEPTH(L3_MAXP_RAM_DEPTH)
    )maxp_buffer_mem_layer3(
        .mem_clk(clk),
        .mem_rst(rst),
        .wr_en_row(wr_en_row_layer3),       //<----input
        .re_en_row(re_en_row_last),       //<----input
        .wr_addr_row(write_address_maxp_layer3),     //<----input
        .re_addr_row(layers_data_read_addr),     //<----input
        .wr_data_row(write_data_maxp_layer3),     //<----input
        .re_data_row(layers_data_out)      //--->output
    );
endmodule
