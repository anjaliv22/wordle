/*******************************************************/
/* Wordle FSM Module                                   */
/*******************************************************/
module wordle_fsm #(
    parameter NUM_LETTERS = 4,                      // Word size in letters
    parameter WORD_WIDTH = NUM_LETTERS * 8,         // Word bitwidth
    parameter RSLT_WIDTH = NUM_LETTERS * 2,         // Result bitwidth
    parameter MAX_GUESSES = 6,                      // Maximum number of allowed guesses
    parameter GUESS_CNTW = $clog2(MAX_GUESSES) + 1  // Bitwidth of guess counter
)(
    input clk,                              // Input clock
    input rstn,                             // Input active-low reset
    input [WORD_WIDTH-1:0] i_ref_word,      // Input reference word
    input [WORD_WIDTH-1:0] i_guess_word,    // Input user guess word
    input [GUESS_CNTW-1:0] i_guess_id,      // Input user guess ID
    output o_ready,                         // Output ready signal (result is valid & ready to accept new guess word)
    output [RSLT_WIDTH-1:0] o_result,       // Output result of a guess (4 letters x 2-bit status: GREEN, YELLOW, GREY)
    output [GUESS_CNTW-1:0] o_guess_count,  // Output number of user guesses so far
    output [1:0] o_game_status              // Output game status (ongoing, user won, user lost)
);

// Declare registers to hold game result, guess count, and status
typedef enum logic [1:0] {GREY=2'b00, GREEN=2'b01, YELLOW=2'b10} result_t;
typedef enum logic [1:0] {ONGOING=2'b00, LOSE=2'b10, WIN=2'b11} status_t;

typedef enum logic [1:0] {ST_INIT, ST_WAIT, ST_PROCESS, ST_STATUS} state_t; //our states!!

state_t state, next_state;

logic r_ready, n_ready;
assign o_ready = r_ready;

//setting up regs -> holds temp vals accross clk edges?
logic [WORD_WIDTH-1:0] r_ref_word, n_ref_word;
logic [WORD_WIDTH-1:0] r_guess_word, n_guess_word;
logic [GUESS_CNTW-1:0] r_prev_guess_id, n_prev_guess_id;
logic [GUESS_CNTW-1:0] r_guess_count, n_guess_count;

status_t r_game_status, n_game_status; //game status being passed 

result_t r_result [0:NUM_LETTERS-1]; //game result 
result_t n_result [0:NUM_LETTERS-1];

localparam logic [GUESS_CNTW-1:0] MAX_GUESSES_V =
    MAX_GUESSES[GUESS_CNTW-1:0];

always_ff @(posedge clk or negedge rstn) begin
    int i;
    if (!rstn) begin //reset is active low so neg edfe
        state <= ST_INIT;
        r_ref_word <= '0;
        r_guess_word <= '0;
        r_prev_guess_id <= '0;
        r_guess_count <= '0;
        r_game_status <= ONGOING;
        r_ready <= 1'b0;
        for (i=0;i<NUM_LETTERS;i++) r_result[i] <= GREY;
    end else begin //so if not reset -> should just trasnition with no cond?
        state <= next_state;
        r_ref_word <= n_ref_word;
        r_guess_word <= n_guess_word;
        r_prev_guess_id <= n_prev_guess_id;
        r_guess_count <= n_guess_count;
        r_game_status <= n_game_status;
        r_ready <= n_ready;
        for (i=0;i<NUM_LETTERS;i++) r_result[i] <= n_result[i]; //loop thorugh lets
    end
end

always_comb begin 
    int ii, jj; //loop variables
    logic [7:0] ref_letter [0:NUM_LETTERS-1]; //reference letters to check against
    logic [7:0] guess_letter [0:NUM_LETTERS-1]; //usr letters 
    logic ref_used [0:NUM_LETTERS-1];
    logic found_match;

    for (ii=0; ii<NUM_LETTERS; ii++) begin
        ref_letter[ii] = r_ref_word  [(NUM_LETTERS-1-ii)*8 +: 8]; //blocking assignment might be  causing the reverse?
        guess_letter[ii] = r_guess_word[(NUM_LETTERS-1-ii)*8 +: 8];
    end

    //reinstantiate vars to be used
    //might be wries cause theyre temp
    next_state = state;
    n_ref_word = r_ref_word;
    n_guess_word = r_guess_word;
    n_prev_guess_id = r_prev_guess_id;
    n_guess_count = r_guess_count;
    n_game_status = r_game_status;
    n_ready  = r_ready;

    for (ii=0; ii<NUM_LETTERS; ii++) begin
        n_result[ii] = r_result[ii];
        ref_used[ii] = 1'b0;
    end

    unique case (state)
        ST_INIT: begin //first state -> reset so like the circle
            n_ref_word = i_ref_word;
            n_prev_guess_id = '0;
            n_guess_count = '0;
            n_game_status = ONGOING;
            n_ready = 1'b1;
            for (ii=0;ii<NUM_LETTERS;ii++) n_result[ii]= GREY; //starting off as grey
            next_state = ST_WAIT; //move onto next state -> wait for usr guess
        end

        ST_WAIT: begin //waiting for usr guess
            n_ready = 1'b1;
            if ((r_game_status == ONGOING) && //game is still happening
                (i_guess_id > r_prev_guess_id)) begin
                n_guess_word = i_guess_word;
                n_prev_guess_id = i_guess_id; //set prev values to hold
                n_ready = 1'b0;
                next_state = ST_PROCESS; //go to nxt state
            end
        end

        ST_PROCESS: begin //state where we compute result
            n_ready = 1'b0;

            // check for green
            for (ii=0; ii<NUM_LETTERS; ii++) begin  //loop through letters 
            //go from left to right (lsb -> msb)
                n_result[ii] = GREY;
                ref_used[ii] = 1'b0;
                if (guess_letter[ii] == ref_letter[ii]) begin
                    n_result[ii] = GREEN; //set to green if right
                    ref_used[ii] = 1'b1;
                end
            end

            // check for yello
            //must handle yellow precedence -> if 2 letters second is yellow 
            for (int k = NUM_LETTERS; k > 0; k--) begin
                ii = k - 1;
                if (n_result[ii] == GREY) begin
                    found_match = 1'b0; //search and find bas
                    for (jj = 0; jj < NUM_LETTERS; jj++) begin
                    //not in right pos and is used wihthin word -> check against ref word and found match
                        if (!ref_used[jj] && (guess_letter[ii] == ref_letter[jj]) && !found_match) begin
                            n_result[ii] = YELLOW;
                            ref_used[jj] = 1'b1;
                            found_match = 1'b1;
                        end
                    end
                end
            end

            n_guess_count = r_guess_count + 1'b1; //increment count
            next_state = ST_STATUS; //move to next state
        end

        ST_STATUS: begin //updates game status
            if (r_game_status == WIN || r_game_status == LOSE) begin
                n_ready = 1'b0;
                if (i_guess_id == '0) next_state = ST_INIT;
            end else begin
            //WIN!!! if the word is fully correct
                if (r_guess_word == r_ref_word) begin
                    n_game_status = WIN;
                    n_ready = 1'b0;
                //LOSE if the word is bad
                end else if (r_guess_count == MAX_GUESSES_V) begin
                    n_game_status = LOSE;
                    n_ready = 1'b0;
                //game is still ongoing
                end else begin
                    n_game_status = ONGOING;
                    n_ready = 1'b1;
                    next_state = ST_WAIT;
                end
            end
        end

        default: next_state = ST_INIT;

    endcase
end


// Connect game result, guess count, and status output ports to the declared corresponding registers
genvar g;
generate
    for (g=0; g<NUM_LETTERS; g++) begin
        assign o_result[(NUM_LETTERS-1-g)*2 +: 2] = r_result[g];
    end
endgenerate

assign o_guess_count = r_guess_count;
assign o_game_status = r_game_status;

endmodule
