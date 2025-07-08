`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 22.06.2025 15:50:08
// Design Name: 
// Module Name: systolic_array
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
//note : relu is implemented in line 348 , its optional but costs MUXes.

module systolic_array#(
    BIT_WIDTH        = 16,
    SA_PIXEL_WIDTH   = 5,
    KERNEL_SIZE      = 3,
    PIX_RAM_DEPTH   = 64,
    KERN_RAM_DEPTH   = 3,
    FEAT_RAM_DEPTH   = 62
)(
    input  logic                                clk,
    input  logic                                rst,
    input  logic                                next_batch,
    //next_batch provisioned for enabling input for next image - for tiled cnn / video cnn applications.
    input  logic                                sa_freeze,
    //this is to HOLD the systolic array in freeze state - nothing moves when sa_freeze is asserted.

    input  logic signed [BIT_WIDTH-1:0]         pixel_rows_i        [0:SA_PIXEL_WIDTH-1],
    output logic [$clog2(PIX_RAM_DEPTH)-1:0]    re_addr_pixel_row   [0:SA_PIXEL_WIDTH-1],

    input  logic signed [BIT_WIDTH-1:0]         kernel_rows_i       [0:KERNEL_SIZE-1],
    output logic [$clog2(KERN_RAM_DEPTH)-1:0]   re_addr_kernel_row  [0:KERNEL_SIZE-1],
    output logic signed [BIT_WIDTH-1:0]         feature_rows_o      [0:SA_PIXEL_WIDTH-KERNEL_SIZE],
    output logic [$clog2(FEAT_RAM_DEPTH)-1:0]   wr_addr_feat_row    [0:SA_PIXEL_WIDTH-KERNEL_SIZE],


    output logic                                feat_mem_ready, 
    //enabled whenever feature column is generated, goes outside the module.
    output logic                                conv_done
    //convolution is done
    );

    localparam FEATURE_SIZE = SA_PIXEL_WIDTH -KERNEL_SIZE + 1;
    localparam SYS_SIZE = SA_PIXEL_WIDTH + KERNEL_SIZE - 1;

    //========== Wires for connections ===================================
    //mesh of SYS_SIZE , to accomodate all wires between PE's and DE's
    logic signed [BIT_WIDTH-1:0] pixel_wires       [0:SYS_SIZE][0:SYS_SIZE];
    logic signed [BIT_WIDTH-1:0] kernel_wires      [0:SYS_SIZE][0:SYS_SIZE];
    logic signed [BIT_WIDTH-1:0] partial_sum_wires [0:SYS_SIZE][0:SYS_SIZE];

    logic                           use_zero_data; 
    // makes input pixels and kernels 0 for bubbling it out.
    logic                           partial_sum_enable_acc [0: FEATURE_SIZE-1]; 
    //wire which connects  to accumulator module, for enabling and disabling.
    logic signed [BIT_WIDTH-1:0]    acc_wire_row [0:SA_PIXEL_WIDTH-KERNEL_SIZE];
    logic                           acc_rst; 
    //resets accumulator to 0 for next window.
    logic                           sa_enable;
    logic                           sa_enable_internal; 
    //for ping pong - read - process matching data with read address - eliminate clock cycle delay mismatch.
    logic signed [BIT_WIDTH-1:0]    feature_wire_row [0:SA_PIXEL_WIDTH-KERNEL_SIZE]; 
    //data out from acc - wire...
    logic signed [BIT_WIDTH-1:0]    feature_buffer_row [0:SA_PIXEL_WIDTH-KERNEL_SIZE]; 
    //register to store acc value.

    assign sa_enable = sa_enable_internal ? (sa_freeze? 0 : 1) : 0;
    //logic (mux)  for reducing enable-hold complexity, sa_enable_internal takes priority to freeze, overriding sa_freeze input.

    //================= MODULE INSTANTIATION MESH =============================
    //Note : Drawing a mesh of SYS_SIZE by hand and marking whenever if conditions are true helps understand how appropriate modules
    //and wires are instantiated and connected respectively.
    //scalable design, fully parametrized.
    genvar i,j;
    generate
        for (i = 0; i < SYS_SIZE; i = i + 1) begin : row_gen
            for (j = 0; j < SYS_SIZE; j = j + 1) begin : col_gen
                // compute cell type
                if (j < SYS_SIZE - i - 1) begin
                    // PE_EMPTY: no instantiation
                end
                else if (i >= SA_PIXEL_WIDTH-1 && j <= i && j >= SYS_SIZE - i - 1 && j >= (KERNEL_SIZE - 1) + (i - (SA_PIXEL_WIDTH - 1))) begin
                    // PE_MAC
                    processing_element #(
                        .BIT_WIDTH(BIT_WIDTH)
                    ) pe_inst (
                        .clk            (clk),
                        .rst            (rst),
                        .pixel_i        (pixel_wires[i][j]),
                        .partial_sum_i  (partial_sum_wires[i][j]),
                        .weight_i       (kernel_wires[i][j]),
                        .pixel_o        (pixel_wires[i+1][j]),
                        .partial_sum_o  (partial_sum_wires[i+1][j+1]),
                        .weight_o       (kernel_wires[i][j+1]),
                        .sa_enable      (sa_enable)
                    );
                end
                else begin
                    // PE_DELAY [DE]
                    delay_element #(
                        .BIT_WIDTH(BIT_WIDTH)
                    ) dl_inst (
                        .clk            (clk),
                        .rst            (rst),
                        .pixel_i        (pixel_wires[i][j]),
                        .weight_i       (kernel_wires[i][j]),
                        .pixel_o        (pixel_wires[i+1][j]),
                        .weight_o       (kernel_wires[i][j+1]),
                        .sa_enable      (sa_enable)
                    );
                end
            end
        end
    endgenerate

    //io connections to SA
    generate
        for (i = 0; i < SYS_SIZE; i = i + 1) begin : row_wire_gen
            for (j = 0; j < SYS_SIZE; j = j + 1) begin : col_wire_gen
                if (j > SYS_SIZE -SA_PIXEL_WIDTH - 1) begin //assign pixel inputs
                    if(j+i == SYS_SIZE-1) begin
                        assign pixel_wires[i][j] = use_zero_data ?'0 : pixel_rows_i[j-(KERNEL_SIZE-1)];
                    end
                end
                if ( i >= SA_PIXEL_WIDTH -1) begin //assign kernel inputs
                    if(j+i == SYS_SIZE-1) begin
                        assign kernel_wires[i][j] = use_zero_data ? '0 : kernel_rows_i[i-(SA_PIXEL_WIDTH-1)];
                    end
                end
                if ( i == SYS_SIZE-1)begin
                    if(j>=SYS_SIZE-FEATURE_SIZE)begin
                        assign acc_wire_row[j-(SYS_SIZE-FEATURE_SIZE)] = partial_sum_wires[i+1][j+1];
                    end
                end
            end
        end
    endgenerate
    
    accumulator_module #(
        .BIT_WIDTH(BIT_WIDTH),
        .KERNEL_SIZE(KERNEL_SIZE),
        .SA_PIXEL_WIDTH(SA_PIXEL_WIDTH)
    )acc_mod_inst(
        .acc_clk(clk),
        .acc_rst(acc_rst||rst), //rst also triggers acc_rst
        .acc_en(partial_sum_enable_acc), //enabled in fsm
        .data_in(acc_wire_row), //always connected to partial sum end row
        .data_out(feature_wire_row),
        .sa_enable(sa_enable)
    );


    //initializations of wires. 
    //To avoid X - no signal conditions affecting the Proper sum propagation, it is set to zero at starting points.
    generate
        for(i = 0 ; i <= SYS_SIZE-1 ; i = i + 1) begin : init_partial_sum_wires_boundary
            for (j = 0 ; j <= SYS_SIZE-1; j++ ) begin
                if(i >= SA_PIXEL_WIDTH-1)begin
                    if(i == SA_PIXEL_WIDTH -1 ) begin
                        if( j <= i && j >= SYS_SIZE- i -1)begin
                            assign partial_sum_wires[i][j] = 0;
                        end
                    end 
                end
            end
        end
    endgenerate

     //----------------------------------------------------------------------------------------------
    //
    //                              ~MAIN LOGIC~
    //
    //----------------------------------------------------------------------------------------------

    //FSM

    logic soft_rst;
    logic [2:0] state, next_state;
    localparam  INIT    = 3'b000,
                PROCESS = 3'b001,
                WR_ACC  = 3'b010,
                DONE_WR = 3'b011,
                FINISH  = 3'b100;

    //state register logic

    always @(posedge clk or posedge rst) begin
        if(rst||soft_rst)begin
            state <= INIT;
        end
        else if (!sa_freeze) begin
            state <= next_state;
        end
    end

    //next state logic signals

    logic   processing_done,
            acc_collect_done,
            writing_done,
            init_done,
            feat_mem_full,
            initialize;

    always_comb begin : nxt_state_logic
        case(state)
            INIT: 
                next_state = (init_done) ? PROCESS : INIT;
            PROCESS:    
                next_state = (processing_done)? WR_ACC : PROCESS;
            WR_ACC:
                next_state = (acc_collect_done)? DONE_WR : WR_ACC;
            DONE_WR: 
                next_state = (writing_done) ? (feat_mem_full ? FINISH : INIT ) : DONE_WR;
            FINISH:     
                next_state = (initialize) ? INIT : FINISH;
            default: 
                next_state = INIT;
        endcase
    end

    //counters and wires for main logic
    localparam  FEAT_CYCLE_MAX   = KERNEL_SIZE + SA_PIXEL_WIDTH + KERNEL_SIZE - 1;

    logic [$clog2(FEAT_CYCLE_MAX+1)-1:0]    sa_cycle_cntr; //accounting for copy clock extra bit is provided.
    logic [$clog2(FEATURE_SIZE)-1:0]        wr_addr_feat_row_num;
    logic [$clog2(FEAT_RAM_DEPTH)-1:0]      large_cycle_cntr; //to help with read_address for pixel
    logic [$clog2(FEAT_RAM_DEPTH+1)-1:0]    wr_addr_counter; //extra bit for handling overflow , overflow value is never used.

    always_comb begin : check_feat_ram_full
        feat_mem_full = 1'b1;
        for (int i = 0; i < FEATURE_SIZE; i++) begin
            if (wr_addr_counter != FEAT_RAM_DEPTH) begin
                feat_mem_full = 1'b0;
            end
        end
    end

    //main logic
    always @(posedge clk or posedge rst) begin
        if(rst||soft_rst) begin
            sa_cycle_cntr <= 0;
            processing_done <= 0;
            acc_collect_done <= 0;
            init_done <= 0;
            writing_done <= 0;
            initialize   <= 0;
            large_cycle_cntr <= 0;
            wr_addr_counter <= 0;
            soft_rst<=0;
            //set read address of pix and kernel to zero (starting position)
            for (int i  = 0; i < SA_PIXEL_WIDTH ; i++) begin
                re_addr_pixel_row[i] <=0;
            end
            for (int i  = 0; i < KERNEL_SIZE ; i++) begin
                re_addr_kernel_row[i] <=0;
            end
            for (int i = 0 ; i < FEATURE_SIZE; i++) begin
                feature_buffer_row[i] <= 0;
                wr_addr_feat_row[i] <= 0;
                partial_sum_enable_acc[i] <= 0;
            end
            feat_mem_ready <= 0;
            use_zero_data  <= 1;
            acc_rst <= 1;
            wr_addr_feat_row_num <= 0;
            sa_enable_internal <=0;
            conv_done<=0;
        end else begin
            case(state)
                INIT: begin
                    sa_cycle_cntr <= 0;
                    processing_done <= 0;
                    acc_collect_done <= 0;
                    writing_done <= 0;
                    initialize   <= 0;
                    init_done <= 1;
                    //note only kernel read address is set back to zero , kernel is looping, but image input is continuous.
                    for (int i  = 0; i < KERNEL_SIZE ; i++) begin
                        re_addr_kernel_row[i] <=0;
                    end
                    
                    for (int i = 0 ; i < FEATURE_SIZE; i++) begin
                        feature_buffer_row[i] <= 0;
                        partial_sum_enable_acc[i] <= 0;
                    end
                    feat_mem_ready <= 0;
                    use_zero_data  <= 0;
                    acc_rst <= 1;
                    wr_addr_feat_row_num <= 0;
                    sa_enable_internal<=0;
                    conv_done<=0;
                end
                
                PROCESS: begin
                    acc_rst <= 0;
                    init_done <= 0;
                    //ping pong style read address increment - process the exact value reflected by read address , eliminate
                    //read address being ahead by one cycle. creating new state costs cycles and bits. this is a mux + 1 bit solution
                    sa_enable_internal <= 1;
                    if(sa_enable_internal)begin
                        sa_cycle_cntr <= sa_cycle_cntr + 1;
                        if(sa_cycle_cntr < KERNEL_SIZE -1)begin
                            use_zero_data <= 0;
                            for (int i  = 0; i < KERNEL_SIZE ; i++) begin
                                re_addr_kernel_row[i] <= re_addr_kernel_row[i] + 1;
                            end
                            for (int i  = 0; i < SA_PIXEL_WIDTH ; i++) begin
                                re_addr_pixel_row[i] <= re_addr_pixel_row[i] + 1;
                            end
                        end else begin
                            use_zero_data <= 1;
                            if(sa_cycle_cntr >= KERNEL_SIZE - 1)begin
                                if(sa_cycle_cntr == FEAT_CYCLE_MAX)begin
                                    for (int i  = 0; i < FEATURE_SIZE ; i++) begin
                                        feature_buffer_row[i] <= feature_wire_row[i]; //copy data to buffer.
                                        processing_done <= 1;
                                    end
                                end else begin
                                    if(wr_addr_feat_row_num < FEATURE_SIZE - 1)begin
                                        wr_addr_feat_row_num <= wr_addr_feat_row_num + 1;
                                    end
                                    partial_sum_enable_acc[wr_addr_feat_row_num] <= 1;
                                end
                            end
                        end
                        sa_enable_internal<= 0;
                    end
                end
                //writes to external buffer/output , write address and data is in sync.
                WR_ACC: begin
                    feat_mem_ready<=1;
                    init_done <=0;
                    sa_cycle_cntr  <= 0;
                    processing_done <= 0;
                    for (int i  = 0; i < FEATURE_SIZE ; i++) begin
                        //ReLU is implemented as optional here
                        if(feature_buffer_row[i] >= 0) begin
                            feature_rows_o[i] <= feature_buffer_row[i]; //output data
                        end else begin
                            feature_rows_o[i] <= 0;
                        end
                        partial_sum_enable_acc[i] <= 0;
                    end
                    acc_collect_done <= 1;
                    if(!acc_collect_done)begin
                        large_cycle_cntr <= large_cycle_cntr + 1;
                    end
                    for (int i  = 0; i < SA_PIXEL_WIDTH ; i++) begin
                        re_addr_pixel_row[i] <= large_cycle_cntr;
                    end
                end
                //increments feature write address, resets buffer.
                DONE_WR: begin
                    feat_mem_ready <= 0;
                    for (int i = 0 ; i < FEATURE_SIZE ; i++ ) begin
                        if(!feat_mem_full && !writing_done )begin
                            wr_addr_feat_row[i] <= wr_addr_feat_row[i] + 1;  
                        end
                        if(!writing_done)begin
                            wr_addr_counter <= wr_addr_counter + 1;
                        end
                        feature_buffer_row[i] <= 0;
                        feature_rows_o[i] <= 0;
                    end
                    
                    writing_done <= 1;
                    processing_done <= 0;
                    acc_collect_done <= 0;
                    init_done <= 0;
                end
                FINISH: begin
                    //state is held here unless next_batch is asserted for next image.
                    wr_addr_counter <= 0;
                    initialize <= next_batch;
                    if(next_batch) soft_rst <= 1;
                    conv_done<= 1;
                end

            endcase
        end
    end
endmodule

