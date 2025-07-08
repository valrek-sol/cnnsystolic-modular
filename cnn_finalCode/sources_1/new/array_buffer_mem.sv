`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan 
// 
// Create Date: 28.06.2025 16:30:05
// Design Name: 
// Module Name: array_buffer_memory
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
// Reads , Writes, enables row wise, 
// addressed column wise.
/*
             address
             |
             |
             |
             V
[ | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | ]  <--- row 0
[ | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | ]
[ | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | ]
....
[ | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | ] <---- row n , n is NUM_LBUFS-1
*/
module array_buffer_memory#(
    NUM_LBUFS = 5,
    BIT_WIDTH = 16,
    RAM_DEPTH = 64
)(
    input mem_clk,
    input mem_rst,
    input  logic wr_en_row [0 : NUM_LBUFS - 1],
    input  logic re_en_row [0 : NUM_LBUFS - 1],
    input  logic [$clog2(RAM_DEPTH)-1:0] wr_addr_row [0 : NUM_LBUFS - 1],
    input  logic [$clog2(RAM_DEPTH)-1:0] re_addr_row [0 : NUM_LBUFS - 1],
    input  logic signed [BIT_WIDTH-1:0] wr_data_row [0 : NUM_LBUFS - 1],
    output logic signed [BIT_WIDTH-1:0] re_data_row [0 : NUM_LBUFS - 1]
);


    //generates NUM_LBUFS number of line buffer memories.
    genvar i;

    generate
        for(i = 0 ; i < NUM_LBUFS ; i = i + 1) begin :input_pix_mem_row
            
            line_buffer_memory #(
                .BIT_WIDTH(BIT_WIDTH),
                .RAM_DEPTH(RAM_DEPTH)
            )input_pix_mem_init(
                .mem_clk(mem_clk),
                .line_mem_rst(mem_rst),
                .wr_en(wr_en_row[i]), 
                .wr_addr(wr_addr_row[i]),
                .wr_data(wr_data_row[i]),
                .re_en(re_en_row[i]),
                .re_addr(re_addr_row[i]),
                .re_data(re_data_row[i])
            );
        end
    endgenerate
endmodule