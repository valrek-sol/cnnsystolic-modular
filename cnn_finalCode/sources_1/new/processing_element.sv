`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 30.05.2025 12:56:29
// Design Name: 
// Module Name: processing_element
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
//     Processing Element for a Systolic Array. To be instantiated in systolic_array module. 
//
// Dependencies: 
// Status:
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module processing_element #(
    BIT_WIDTH = 16 //[ Q0.15 fixed point signed] - match with MAC.
)(
    input  logic                        clk,
    input  logic                        rst,
    input  logic signed [BIT_WIDTH-1:0] pixel_i,
    input  logic signed [BIT_WIDTH-1:0] partial_sum_i,
    input  logic signed [BIT_WIDTH-1:0] weight_i,
    output logic signed [BIT_WIDTH-1:0] weight_o,
    output logic signed [BIT_WIDTH-1:0] pixel_o,
    output logic signed [BIT_WIDTH-1:0] partial_sum_o,
    input  logic                        sa_enable
    );

    logic signed [BIT_WIDTH-1:0] mac;
    logic mac_en = 1; //provision was given for modularity. Always enabled in this case to reduce complexity.

    multiply_accumulate #(
        .BIT_WIDTH(BIT_WIDTH)
    ) mult_inst (
        .operand_a(pixel_i),
        .operand_b(weight_i),
        .operand_c(partial_sum_i),
        .mac_en(mac_en), 
        .mac(mac)
    );

    always @(posedge clk) begin
        if(rst) begin
            pixel_o <= 0;
            weight_o <= 0;
            partial_sum_o <= 0;
        end else begin
            if(sa_enable) begin
                pixel_o <= pixel_i;
                weight_o <= weight_i;
                partial_sum_o <= mac;
            end else begin //when sa_array is freezed (sa_enable == 0) , HOLD the values as is , to FREEZE systolic array in time.
                pixel_o <= pixel_o;
                weight_o <= weight_o;
                partial_sum_o <= partial_sum_o;
            end
        end
    end

endmodule
