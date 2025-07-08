`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Guru Charan
// 
// Create Date: 2.06.2025 14:38
// Design Name: 
// Module Name: multiply_accumulate
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
//     Multiply Accumulate for Fixed Point Numbers [q0.15 - signed fixed point ]
//
// Dependencies: 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module multiply_accumulate #(
    parameter BIT_WIDTH = 16  // Q0.15 fixed point signed
)(
    input  logic signed [BIT_WIDTH-1:0] operand_a, 
    input  logic signed [BIT_WIDTH-1:0] operand_b, 
    input  logic signed [BIT_WIDTH-1:0] operand_c,
    input  logic mac_en,
    output logic signed [BIT_WIDTH-1:0] mac        
);

    // Internal signals
    logic signed [2*BIT_WIDTH-1:0] product_full;
    logic signed [BIT_WIDTH-1:0]   product_q15;
    logic signed [BIT_WIDTH:0]     mac_temp;  // one extra bit for overflow

    always @(*) begin
        if (mac_en) begin
            product_full = operand_a * operand_b;
            // Truncate to Q0.15
            product_q15 = product_full[BIT_WIDTH + 14 : 15];
            mac_temp = product_q15 + operand_c;
        end else begin
            mac_temp = '0;
        end

        
        // Saturation logic
        if (mac_temp > $signed(16'sh7FFF)) begin
            mac = 16'sh7FFF;
        end else if (mac_temp < $signed(16'sh8000)) begin
            mac = 16'sh8000;
        end else begin
            mac = mac_temp[BIT_WIDTH-1:0];
        end
    end

endmodule

