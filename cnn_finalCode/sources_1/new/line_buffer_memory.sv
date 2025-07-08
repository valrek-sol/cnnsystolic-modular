`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan P
// 
// Create Date: 28.06.2025 16:30:51
// Design Name: 
// Module Name: line_buffer_memory
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:  Dual port line buffer memory.
// Designed to be friendly with systolic array ; 
//reason : to feed rows of images parallely to the array, 
//increment uniformly to the next column in this case (data read column wise.)
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/*
            address (column index)
             |
             |
             V
[ | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | ] <-- row
*/
module line_buffer_memory#(
    BIT_WIDTH = 16,
    RAM_DEPTH = 64
)(
    input mem_clk,
    input line_mem_rst,
    //Port A : write
    input  logic wr_en, //write enable
    input  logic [$clog2(RAM_DEPTH)-1:0] wr_addr, //write address
    input  logic [BIT_WIDTH-1:0] wr_data, // write data
    //Port B : read
    input  logic re_en, //read enable
    input  logic [$clog2(RAM_DEPTH)-1:0] re_addr, // read address
    output logic [BIT_WIDTH-1:0] re_data //read data
    );

    logic [BIT_WIDTH-1:0] mem [RAM_DEPTH-1:0]; //line memory register

    //Port A : write
    always @(posedge mem_clk) begin
        if (line_mem_rst) begin
            for(integer i = 0 ; i < RAM_DEPTH ; i = i + 1) begin
                mem[i] <= 0;
            end
        end else if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end
    //Port B : read
    always @(posedge mem_clk) begin
        if (re_en) begin
            re_data <= mem[re_addr];
        end
    end

endmodule