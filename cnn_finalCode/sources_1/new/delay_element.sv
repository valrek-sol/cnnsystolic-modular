`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 22.06.2025 18:41:37
// Design Name: 
// Module Name: delay_element
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// Pass the pixels and kernels to the neighboring pe's or de's in the systolic array, consumes one clk cycle to match rythm.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module delay_element#(
    BIT_WIDTH = 16 //[ Q0.15 fixed point signed] - match with MAC.
)(
    input  logic                        clk,
    input  logic                        rst,
    input  logic                        sa_enable,
    input  logic signed [BIT_WIDTH-1:0] pixel_i,
    input  logic signed [BIT_WIDTH-1:0] weight_i,
    output logic signed [BIT_WIDTH-1:0] weight_o,
    output logic signed [BIT_WIDTH-1:0] pixel_o
    );
    always @(posedge clk) begin
        if(rst) begin
            pixel_o <= 0;
            weight_o <= 0;
        end else begin
            if(sa_enable)begin
                pixel_o <= pixel_i;
                weight_o <= weight_i;
            end else begin //when sa_array is freezed (sa_enable == 0) , HOLD the values as is , to FREEZE systolic array in time.
                pixel_o <= pixel_o;
                weight_o <= weight_o;
            end
        end
    end
endmodule
