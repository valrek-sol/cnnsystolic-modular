`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Guru Charan
// 
// Create Date: 29.06.2025 02:44:22
// Design Name: 
// Module Name: maxpool_module#
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


module maxpool_module#(
    BIT_WIDTH = 16,
    FEAT_PIX_WIDTH = 3,
    FEAT_RAM_DEPTH = 62,
    MAX_POOL_SIZE = 3, //usually 2
    MAX_POOL_STRIDE = 2 //usually 2. check bounds to avoid skipping.
)(
    input                                       clk, 
    //clk from current layer
    input                                       rst,
    input                                       maxp_module_enable, 
    //fsm moves to next state only if asserted.
    input                                       next_batch, 
    //to do a soft reset ; provisioned for modularity incase of scaling system to tiled/ multiple images or video cnn.
    input  logic signed [BIT_WIDTH-1:0]         feat_re_data_in_row     [0 : FEAT_PIX_WIDTH - 1],
    output logic [$clog2(FEAT_RAM_DEPTH)-1:0]   feat_col_re_addr_row    [0:FEAT_PIX_WIDTH-1],
    output logic signed [BIT_WIDTH-1:0]         maxp_data_out_row       [0:(((FEAT_PIX_WIDTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1],
    output logic [$clog2(((FEAT_RAM_DEPTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1:0] maxp_col_wr_addr_row [0:(((FEAT_PIX_WIDTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1)-1],
    //above arithmetic is just parametrization given locally below , 
    //but local param cannot be used, hence the derived arithmetic from given params above.
    output logic                                data_ready_o,
    output logic                                maxp_done
);

    localparam MAXP_PIX_WIDTH = ((FEAT_PIX_WIDTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;
    localparam MAXP_RAM_DEPTH = ((FEAT_RAM_DEPTH - MAX_POOL_SIZE)/MAX_POOL_STRIDE)+1;

    localparam VALID_PIX_WIDTH = (((FEAT_PIX_WIDTH-MAX_POOL_SIZE)/MAX_POOL_STRIDE)*MAX_POOL_STRIDE)+MAX_POOL_SIZE;
    localparam VALID_RAM_DEPTH = (((FEAT_RAM_DEPTH-MAX_POOL_SIZE)/MAX_POOL_STRIDE)*MAX_POOL_STRIDE)+MAX_POOL_SIZE;



    //FSM
    logic soft_rst;
    logic [2:0] state, next_state;
    localparam  INIT = 3'b000,
                FIND_MAX = 3'b001,
                SEND_MAX = 3'b010,
                DONE_WR   = 3'b011,
                FINISH    = 3'b100;
    // state logic 
    always @(posedge clk or posedge rst) begin
        if(rst||soft_rst)begin
            state <= INIT;
        end
        else if (maxp_module_enable) begin
            state <= next_state;
        end
    end
    //logic control signals
    logic   init_done,
            findmax_done,
            sendmax_done,
            writing_done,
            maxp_mem_full,
            initialize;
    //next state logic using control signals
    always_comb begin : nxt_state_logic
        case(state)
            INIT: 
                next_state = (init_done) ? FIND_MAX : INIT;
            FIND_MAX:    
                next_state = (findmax_done)? SEND_MAX : FIND_MAX;
            SEND_MAX:
                next_state = (sendmax_done)? DONE_WR : SEND_MAX;
            DONE_WR: 
                next_state = (writing_done) ? (maxp_mem_full ? FINISH : INIT ) : DONE_WR;
            FINISH:     
                next_state = (initialize) ? INIT : FINISH;
            default: 
                next_state = INIT;
        endcase
    end

    logic [$clog2(MAXP_RAM_DEPTH+1)-1:0]wr_addr_counter; 
    //extra bit for handling overflow in the extra cycle - increment
    logic maxp_internal_enable; 
    //internal enable to defreeze maxpooler , for ping pong style addr increment and processing current read address- data
    logic [$clog2(MAX_POOL_SIZE+1)-1:0]maxp_findmax_counter;  
    //to bound current flow within MAXPOOLSIZE , +1 bit for handling overflow
    logic signed [BIT_WIDTH-1:0] maxp_current_buffer [0:MAXP_PIX_WIDTH-1];
    //holds recent maxpool values. refreshed back to minimum after every POOL window.

    //check if memory is full - end of maxpooling process - send ready signal
    always_comb begin : check_maxp_ram_full
        maxp_mem_full = 1'b1;
        if (wr_addr_counter != MAXP_RAM_DEPTH) begin
            maxp_mem_full = 1'b0;
        end
    end
    
    always @(posedge clk or posedge rst) begin
        if(rst|| soft_rst) begin
            init_done <= 0;
            findmax_done<=0;
            sendmax_done<=0;
            writing_done<=0;
            initialize<=0;
            wr_addr_counter<=0;
            soft_rst<=0;
            maxp_internal_enable <=0;
            maxp_findmax_counter<=0;
            for(int i = 0 ; i < MAXP_PIX_WIDTH; i++) begin
                maxp_current_buffer[i] = 1 <<< (BIT_WIDTH-1); //minimum signed value. (-1) 16'h8000.
            end
            //set read address of accessing feature buffer at starting point (0)
            for (int i  = 0; i < FEAT_PIX_WIDTH ; i++) begin
                feat_col_re_addr_row[i] <=0;
            end
            //set write address to zero ,to write to maxpooling buffer
            for (int i = 0 ; i < MAXP_PIX_WIDTH; i++) begin
                maxp_col_wr_addr_row[i] <= 0;
            end
            data_ready_o<=0;
            maxp_done<=0;
        end else begin
            case (state)
                INIT: begin
                    //sets buffer to minimum value , DOES NOT RESET read or write addresses.
                    //resets internal counters.
                    init_done <= 1;
                    findmax_done<=0;
                    sendmax_done<=0;
                    writing_done<=0;
                    initialize<=0;
                    for (int i = 0 ; i < MAXP_PIX_WIDTH; i++) begin
                        maxp_current_buffer[i] <= 1 <<< (BIT_WIDTH-1);
                    end
                    data_ready_o <=0;
                    maxp_findmax_counter<=0;
                    maxp_internal_enable <=1;
                end

                FIND_MAX: begin
                    //ping pong read address increment - get data after the clock delay - process technique.
                    //without maxp_internal enable , read address and data is mismatched by one clock cycle.
                    if(maxp_internal_enable)begin
                        for(int i = 0 ; i < MAXP_PIX_WIDTH ; i++)begin
                            for(int j = 0 ; j < MAX_POOL_SIZE; j++)begin 
                                if(maxp_current_buffer[i] < feat_re_data_in_row[(i*MAX_POOL_STRIDE)+j])begin
                                    maxp_current_buffer[i] <= feat_re_data_in_row[(i*MAX_POOL_STRIDE)+j];
                                end
                            end
                        end
                        maxp_internal_enable <= 0;
                    end else begin
                        if(maxp_findmax_counter < MAX_POOL_SIZE -1)begin
                            for(int i = 0 ; i < VALID_PIX_WIDTH  ; i++)begin
                                feat_col_re_addr_row[i] <= (feat_col_re_addr_row[i] + 1 < VALID_RAM_DEPTH)? (feat_col_re_addr_row[i] + 1): (VALID_RAM_DEPTH - 1);
                            end
                        end else begin
                            findmax_done <= 1;
                            for(int i = 0 ; i < VALID_PIX_WIDTH  ; i++)begin
                                feat_col_re_addr_row[i] <= (feat_col_re_addr_row[i] + 1 < VALID_RAM_DEPTH)? (feat_col_re_addr_row[i] + 1): (VALID_RAM_DEPTH - 1);
                            end
                        end
                        maxp_findmax_counter <= maxp_findmax_counter + 1;
                        maxp_internal_enable <=1;
                    end
                    init_done<=0;
                end

                SEND_MAX: begin
                    //sends data outside the module , a whole column is sent.
                    maxp_findmax_counter<=0;
                    findmax_done <= 0;
                    for(int i = 0 ; i < MAXP_PIX_WIDTH ; i++)begin
                        maxp_data_out_row[i]<= maxp_current_buffer[i];
                    end
                    data_ready_o <=1;
                    sendmax_done<=1;
                end

                DONE_WR: begin
                    data_ready_o<=0;
                    //increments write address if not complete, if complete, then it goes to FINISH.
                    for(int i = 0 ; i < MAXP_PIX_WIDTH ; i++)begin
                        if(!maxp_mem_full&&!writing_done)begin
                            maxp_col_wr_addr_row[i]<= maxp_col_wr_addr_row[i] + 1;
                        end
                        if(!writing_done)begin
                            wr_addr_counter <= wr_addr_counter+1;
                        end
                        maxp_data_out_row[i] <= 0;
                    end
                    writing_done<=1;
                end

                FINISH: begin
                    //stays here until next_batch is asserted.
                    wr_addr_counter<=0;
                    initialize <= next_batch;
                    if(next_batch) soft_rst <= 1;
                    maxp_done <=1;
                end
            endcase
        end
    end

endmodule
