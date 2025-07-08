`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 01.07.2025 13:37:30
// Design Name: 
// Module Name: tb_cnn_system_3_layer
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
// note : in simulator , adjust simulation duration setting, 1000ns is not sufficient, set around 37,000ns or above.


module tb_cnn_system_3_layer;

    localparam IMG_HEIGHT      = 32;
    localparam KERNEL_SIZE     = 3;
    localparam IMG_WIDTH       = 32;
    localparam BIT_WIDTH       = 16;
    localparam MAX_POOL_SIZE   = 2;
    localparam MAX_POOL_STRIDE = 2;


    // Layer 1 dimensions
    localparam L1_FEAT_PIX_WIDTH = IMG_HEIGHT - KERNEL_SIZE + 1;
    localparam L1_FEAT_RAM_DEPTH = IMG_WIDTH - KERNEL_SIZE + 1;
    localparam L1_MAXP_PIX_WIDTH = ((L1_FEAT_PIX_WIDTH - MAX_POOL_SIZE) / MAX_POOL_STRIDE) + 1;
    localparam L1_MAXP_RAM_DEPTH = ((L1_FEAT_RAM_DEPTH - MAX_POOL_SIZE) / MAX_POOL_STRIDE) + 1;

    // Layer 2 dimensions
    localparam L2_FEAT_PIX_WIDTH = L1_MAXP_PIX_WIDTH - KERNEL_SIZE + 1;
    localparam L2_FEAT_RAM_DEPTH = L1_MAXP_RAM_DEPTH - KERNEL_SIZE + 1;
    localparam L2_MAXP_PIX_WIDTH = ((L2_FEAT_PIX_WIDTH - MAX_POOL_SIZE) / MAX_POOL_STRIDE) + 1;
    localparam L2_MAXP_RAM_DEPTH = ((L2_FEAT_RAM_DEPTH - MAX_POOL_SIZE) / MAX_POOL_STRIDE) + 1;

    // Layer 3 dimensions (Final Output)
    localparam L3_FEAT_PIX_WIDTH = L2_MAXP_PIX_WIDTH - KERNEL_SIZE + 1;
    localparam L3_FEAT_RAM_DEPTH = L2_MAXP_RAM_DEPTH - KERNEL_SIZE + 1;
    localparam L3_MAXP_PIX_WIDTH = ((L3_FEAT_PIX_WIDTH - MAX_POOL_SIZE) / MAX_POOL_STRIDE) + 1;
    localparam L3_MAXP_RAM_DEPTH = ((L3_FEAT_RAM_DEPTH - MAX_POOL_SIZE) / MAX_POOL_STRIDE) + 1;


    // --- Signal Declarations ---

    logic clk;
    logic rst;

    // Inputs to drive the DUT
    logic                                    wr_en_img_row    [0:IMG_HEIGHT-1];
    logic [$clog2(IMG_WIDTH)-1:0]            wr_addr_img_row  [0:IMG_HEIGHT-1];
    logic signed [BIT_WIDTH-1:0]             wr_data_img_row  [0:IMG_HEIGHT-1];
    logic                                    img_buff_valid;

    logic                                    wr_en_kern_row   [0:KERNEL_SIZE-1];
    logic [$clog2(KERNEL_SIZE)-1:0]          wr_addr_kern_row [0:KERNEL_SIZE-1];
    logic signed [BIT_WIDTH-1:0]             wr_data_kern_row [0:KERNEL_SIZE-1];
    logic                                    kern_buff_valid;

    logic [$clog2(L3_MAXP_RAM_DEPTH)-1:0]     layers_data_read_addr [0:L3_MAXP_PIX_WIDTH-1];

    // Outputs to monitor from the DUT
    logic signed [BIT_WIDTH-1:0]             layers_data_out [0:L3_MAXP_PIX_WIDTH-1];
    logic                                    layers_done;

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period, 100MHz clock
    end

    cnn_system_3_layer #(
        .IMG_HEIGHT(IMG_HEIGHT),
        .KERNEL_SIZE(KERNEL_SIZE),
        .IMG_WIDTH(IMG_WIDTH),
        .BIT_WIDTH(BIT_WIDTH),
        .MAX_POOL_SIZE(MAX_POOL_SIZE),
        .MAX_POOL_STRIDE(MAX_POOL_STRIDE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en_img_row(wr_en_img_row),
        .wr_addr_img_row(wr_addr_img_row),
        .wr_data_img_row(wr_data_img_row),
        .img_buff_valid(img_buff_valid),
        .wr_en_kern_row(wr_en_kern_row),
        .wr_addr_kern_row(wr_addr_kern_row),
        .wr_data_kern_row(wr_data_kern_row),
        .kern_buff_valid(kern_buff_valid),
        .layers_data_read_addr(layers_data_read_addr),
        .layers_data_out(layers_data_out),
        .layers_done(layers_done)
    );

    // Main test sequence
    initial begin
        $display("Starting simulation...");
        // 1. Initialize all signals and apply reset
        rst = 1;
        img_buff_valid  = 0;
        kern_buff_valid = 0;


        foreach (wr_en_img_row[i]) begin
            wr_en_img_row[i]   = 0;
            wr_addr_img_row[i] = 0;
            wr_data_img_row[i] = 0;
        end

        foreach (wr_en_kern_row[i]) begin
            wr_en_kern_row[i]   = 0;
            wr_addr_kern_row[i] = 0;
            wr_data_kern_row[i] = 0;
        end
        
        foreach (layers_data_read_addr[i]) begin
            layers_data_read_addr[i] = 0;
        end

        #20;
        rst = 0;
        $display("Reset released.");

        // 2. Load the Kernel data
        $display("Loading kernel...");
        for (int addr = 0; addr < KERNEL_SIZE; addr++) begin
            @(posedge clk);
            for (int k = 0; k < KERNEL_SIZE; k++) begin
                wr_en_kern_row[k]   = 1;
                wr_addr_kern_row[k] = addr;
                wr_data_kern_row[k] = 16'h0039; // 0.1 in Q0.15 signed fixed point
            end
        end
        @(posedge clk);
        foreach (wr_en_kern_row[k]) wr_en_kern_row[k] = 0;
        kern_buff_valid = 1;
        $display("Kernel loading complete. kern_buff_valid asserted.");

        // 3. Load the Image pixel data
        $display("Loading image data...");
        for (int addr = 0; addr < IMG_WIDTH; addr++) begin
            @(posedge clk);
            for (int p = 0; p < IMG_HEIGHT; p++) begin
                wr_en_img_row[p]   = 1;
                wr_addr_img_row[p] = addr;
                wr_data_img_row[p] = 16'h0313 * (addr + p); // Random pixel values
            end
        end
        @(posedge clk);
        foreach (wr_en_img_row[p]) wr_en_img_row[p] = 0;
        img_buff_valid = 1;
        $display("Image loading complete. img_buff_valid asserted.");

        // 4. Wait for the entire 3-layer process to complete
        $display("Waiting for all CNN layers to complete...");
        wait (layers_done);
        $display("DUT finished processing. layers_done is high.");

        @(posedge clk);

        // 5. Read out the final feature map from the last layer
        $display("Reading final feature map (Expected size: %0d x %0d)...", L3_MAXP_PIX_WIDTH, L3_MAXP_RAM_DEPTH);
        for (int addr = 0; addr < L3_MAXP_RAM_DEPTH; addr++) begin
            @(posedge clk);
            // Set the address to read for all parallel output RAMs
            for (int i = 0; i < L3_MAXP_PIX_WIDTH; i++) begin
                layers_data_read_addr[i] = addr;
            end

            // Data is available on the next clock edge after setting the address
            @(posedge clk);
            $write("Output Row[%0d]: ", addr);
            for (int i = 0; i < L3_MAXP_PIX_WIDTH; i++) begin
                $write("%h ", layers_data_out[i]);
            end
            $write("\n");
        end

        @(posedge clk);

        #20;
        $display("Simulation completed.");
        $finish;
    end

endmodule
