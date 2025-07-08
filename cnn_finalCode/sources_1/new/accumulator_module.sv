`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan 
// 
// Create Date: 27.06.2025 10:38:51
// Design Name: 
// Module Name: accumulator_module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
/*
ACCUMULATOR MAIN FUNCTION : ACCUMULATE INCOMING DATA INDEFINITELY UNTIL RESET
DATA TYPE : Should match multiply accumulate module data format
Designed to use along with Systolic array primarily.
*/
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module accumulator_module#(
    parameter BIT_WIDTH = 16,            
    parameter KERNEL_SIZE = 3,
    parameter SA_PIXEL_WIDTH = 5  
)(
    input  logic acc_clk,                //synced with global main clock (systolic array clock)
    input  logic acc_rst,                //rst resets value stored inside accumulator
    input  logic acc_en [0:SA_PIXEL_WIDTH-KERNEL_SIZE], //connected to valid signal from systolic array, enables accumulation
    input  logic sa_enable,                             //this and acc_en , when de asserted, holds the value [DOES NOT CLEAR VALUES]
    input  logic signed [BIT_WIDTH-1:0] data_in [0:SA_PIXEL_WIDTH-KERNEL_SIZE], //signed is preferred for CNNs early layers.
    output logic signed [BIT_WIDTH-1:0] data_out[0:SA_PIXEL_WIDTH-KERNEL_SIZE]
);
    localparam FEATURE_SIZE = SA_PIXEL_WIDTH - KERNEL_SIZE + 1;
    // Wider internal accumulators to avoid overflow - optimal size calculated as 
    //(2 x Kernel size -1) x bit-width for systolic arrays
    localparam ACC_BIT_WIDTH = ((2*KERNEL_SIZE)-1)*BIT_WIDTH;
    logic signed [ACC_BIT_WIDTH-1:0] accum_reg [0:FEATURE_SIZE-1];


    // Accumulation logic
    always_ff @(posedge acc_clk or posedge acc_rst) begin
        if (acc_rst) begin
            for (int i = 0; i < FEATURE_SIZE; i = i + 1) begin
                accum_reg[i] <= '0;
            end
        end else begin
            for (int i = 0; i < FEATURE_SIZE; i = i + 1) begin
                if(acc_en[i] && sa_enable)begin
                    accum_reg[i] <= accum_reg[i] + data_in[i];
                end else begin
                    accum_reg[i] <= accum_reg[i];
                end
            end
        end
    end

    // Output saturation to data type range [fixed point signed q0.15] - must match with MAC module.
    always_comb begin
        for (int i = 0; i < FEATURE_SIZE; i = i + 1) begin
            if (accum_reg[i] > $signed(16'sh7FFF)) begin
                data_out[i] = 16'sh7FFF;
            end else if (accum_reg[i] < $signed(16'sh8000)) begin
                data_out[i] = 16'sh8000;
            end else begin
                data_out[i] = accum_reg[i][BIT_WIDTH-1:0];  // Truncate
            end
        end
    end

endmodule

