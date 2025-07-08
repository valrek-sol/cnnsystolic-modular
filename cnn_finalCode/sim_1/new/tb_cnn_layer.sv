`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 01.07.2025 20:09:11
// Design Name: 
// Module Name: tb_cnn_layer
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


module tb_cnn_layer;

    // --- Parameters ---
    localparam SA_PIXEL_WIDTH = 12;
    localparam KERNEL_SIZE = 3;
    localparam PIX_RAM_DEPTH = 12;
    localparam BIT_WIDTH = 16;
    localparam MAX_POOL_STRIDE = 2;
    localparam MAX_POOL_SIZE = 2;

    // Derived parameters for clarity
    localparam FEAT_PIX_WIDTH = SA_PIXEL_WIDTH - KERNEL_SIZE + 1;
    localparam FEAT_RAM_DEPTH = PIX_RAM_DEPTH - KERNEL_SIZE + 1;
    localparam MAXP_PIX_WIDTH = ((FEAT_PIX_WIDTH - MAX_POOL_SIZE) / MAX_POOL_STRIDE) + 1;
    localparam MAXP_RAM_DEPTH = ((FEAT_RAM_DEPTH - MAX_POOL_SIZE) / MAX_POOL_STRIDE) + 1;

    // --- Testbench Signals ---
    logic clk;
    logic rst;

    // --- Connections to DUT ---

    // To DUT: Pixel data and valid signal
    logic signed [BIT_WIDTH-1:0]       read_data_pix[0:SA_PIXEL_WIDTH-1];
    logic                              pix_data_in_valid_in;

    // From DUT: Pixel read request
    logic                              read_enable_pix[0:SA_PIXEL_WIDTH-1];
    logic [$clog2(PIX_RAM_DEPTH)-1:0]  read_address_pix[0:SA_PIXEL_WIDTH-1];

    // To DUT: Kernel data and valid signal
    logic signed [BIT_WIDTH-1:0]       read_data_kern[0:KERNEL_SIZE-1];
    logic                              kern_data_in_valid_in;

    // From DUT: Kernel read request
    logic                              read_enable_kern[0:KERNEL_SIZE-1];
    logic [$clog2(KERNEL_SIZE)-1:0]    read_address_kern[0:KERNEL_SIZE-1];

    // From DUT: Maxpool output data and control signals
    logic [$clog2(MAXP_RAM_DEPTH)-1:0] write_address_maxp[0:MAXP_PIX_WIDTH-1];
    logic signed [BIT_WIDTH-1:0]       write_data_maxp[0:MAXP_PIX_WIDTH-1];
    logic                              maxp_data_out_valid_out;
    logic                              layer_done;

    // --- Testbench Memory Emulation ---
    // These arrays model the external memories that store pixels, kernels, and results.
    logic signed [BIT_WIDTH-1:0] pix_mem [0:SA_PIXEL_WIDTH-1][0:PIX_RAM_DEPTH-1];
    logic signed [BIT_WIDTH-1:0] kern_mem[0:KERNEL_SIZE-1][0:KERNEL_SIZE-1];
    logic signed [BIT_WIDTH-1:0] maxp_out_mem[0:MAXP_PIX_WIDTH-1][0:MAXP_RAM_DEPTH-1];

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- DUT Instantiation (Corrected Ports) ---
    cnn_layer #(
        .SA_PIXEL_WIDTH(SA_PIXEL_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .PIX_RAM_DEPTH(PIX_RAM_DEPTH),
        .BIT_WIDTH(BIT_WIDTH),
        .MAX_POOL_STRIDE(MAX_POOL_STRIDE),
        .MAX_POOL_SIZE(MAX_POOL_SIZE)
    ) dut (
        .clk(clk),
        .rst(rst),

        // Pixel Interface
        .read_enable_pix(read_enable_pix),
        .read_address_pix(read_address_pix),
        .read_data_pix(read_data_pix),
        .pix_data_in_valid_in(pix_data_in_valid_in),

        // Kernel Interface
        .read_enable_kern(read_enable_kern),
        .read_address_kern(read_address_kern),
        .read_data_kern(read_data_kern),
        .kern_data_in_valid_in(kern_data_in_valid_in),

        // Maxpool Output Interface
        .write_address_maxp(write_address_maxp),
        .write_data_maxp(write_data_maxp),
        .maxp_data_out_valid_out(maxp_data_out_valid_out),
        .layer_done(layer_done)
    );

    // --- Memory Read Logic ---
    // This logic emulates the external memory's read ports.
    // It combinationally provides data to the DUT based on its read requests.
    genvar i, j, k;
    generate
        // Pixel Memory Read Port
        for (i = 0; i < SA_PIXEL_WIDTH; i++) begin : pixel_read_logic
            // Note: This models a zero-latency read. For a more realistic memory,
            // you might add a register stage here.
            assign read_data_pix[i] = pix_mem[i][read_address_pix[i]];
        end

        // Kernel Memory Read Port
        for (j = 0; j < KERNEL_SIZE; j++) begin : kernel_read_logic
            assign read_data_kern[j] = kern_mem[j][read_address_kern[j]];
        end
    endgenerate

    // --- Output Capture Logic ---
    // This process waits for the DUT to provide valid output data
    // and stores it in the testbench's output memory.
    always_ff @(posedge clk) begin
        if (rst) begin
             // Optionally clear the output memory on reset
            for (int row = 0; row < MAXP_RAM_DEPTH; row++) begin
                for (int col = 0; col < MAXP_PIX_WIDTH; col++) begin
                    maxp_out_mem[col][row] <= 0;
                end
            end
        end else if (maxp_data_out_valid_out) begin
            $display("T=%0t: Capturing maxpool output data.", $time);
            for (int col = 0; col < MAXP_PIX_WIDTH; col++) begin
                // Capture the data into the corresponding location
                maxp_out_mem[col][write_address_maxp[col]] <= write_data_maxp[col];
            end
        end
    end

    // --- Main Test Scenario ---
    initial begin
        rst = 1;
        pix_data_in_valid_in = 0;
        kern_data_in_valid_in = 0;
        $display("T=%0t: System Reset Asserted.", $time);
        #20;
        rst = 0;
        $display("T=%0t: System Reset De-asserted.", $time);
        @(posedge clk);

        // === KERNEL MEMORY LOAD (in Testbench) ===
        $display("T=%0t: Loading kernel data into testbench memory...", $time);
        for (int row = 0; row < KERNEL_SIZE; row++) begin
            for (int col = 0; col < KERNEL_SIZE; col++) begin
                // All kernel weights are 1 for simplicity
                kern_mem[col][row] = 16'h0036;
            end
        end
        kern_data_in_valid_in = 1; // Signal to DUT that kernel memory is ready
        $display("T=%0t: Kernel data ready.", $time);

        // === PIXEL MEMORY LOAD (in Testbench) ===
        $display("T=%0t: Loading pixel data into testbench memory...", $time);
        for (int row = 0; row < PIX_RAM_DEPTH; row++) begin
            for (int col = 0; col < SA_PIXEL_WIDTH; col++) begin
                // Loading with a simple pattern
                pix_mem[col][row] = 16'h0312 * (row + col);
            end
        end
        pix_data_in_valid_in = 1; // Signal to DUT that pixel memory is ready
        $display("T=%0t: Pixel data ready. DUT should start processing.", $time);

        // Wait for convolution + maxpooling to complete
        wait (layer_done);
        $display("T=%0t: DUT signaled layer_done. Convolution + MaxPooling finished.", $time);

        @(posedge clk);

        // === READ OUT (from Testbench Memory) ===
        $display("\n--- Reading Final Output from Testbench Memory ---");
        for (int row = 0; row < MAXP_RAM_DEPTH; row++) begin
            $write("Output Row[%0d]: ", row);
            for (int col = 0; col < MAXP_PIX_WIDTH; col++) begin
                $write("%h ", maxp_out_mem[col][row]);
            end
            $write("\n");
        end
        $display("--- End of Final Output ---");

        #20;
        $display("T=%0t: Simulation completed.", $time);
        $finish;
    end

endmodule

