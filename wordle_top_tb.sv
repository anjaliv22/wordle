/*******************************************************/
/* Wordle Game Testbench (C-COMPAT RESULT PARSING)     */
/*******************************************************/

`timescale 1ns / 1ps

// Define the name of this testbench module. Since testbenches typically generate inputs and
// monitor outputs of the circuit being tested, they usually do not have any input/output ports.
module wordle_top_tb();

localparam CLK_PERIOD = 2;                          // Clock period in nanoseconds
localparam NUM_LETTERS = 4;                         // Word size in letters
localparam WORD_WIDTH = NUM_LETTERS * 8;            // Word bitwidth
localparam RSLT_WIDTH = NUM_LETTERS * 2;            // Result bitwidth
localparam MAX_GUESSES = 6;                         // Maximum number of allowed guesses
localparam GUESS_CNTW = $clog2(MAX_GUESSES) + 1;    // Bitwidth of guess counter
localparam DICT_SIZE = 1024;                        // Depth of the word ROM
localparam ADDR_WIDTH = $clog2(DICT_SIZE);          // Bitwidth of ROM address

// Declare logic signals for the circuit's inputs/outputs
logic clk;
logic rstn;
logic [ADDR_WIDTH-1:0] i_ref_word_idx;
logic [WORD_WIDTH-1:0] i_guess_word;
logic [GUESS_CNTW-1:0] i_guess_id;
logic o_ready;
logic [RSLT_WIDTH-1:0] o_result;
logic [GUESS_CNTW-1:0] o_guess_count;
logic [1:0] o_game_status;

// Signal to identify if simulation passed (1'b0) or failed (1'b1). Your testbench should test
// the design and set this signal accordingly.
logic sim_failed;


logic [RSLT_WIDTH-1:0]  prev_res; //previous result
logic [GUESS_CNTW-1:0]  prev_cnt; //previous guess count

// Instantiate the design under test (dut), set the desired values of its parameters, and connect
// its input/output ports to the declared signals.
wordle_top dut (
    .clk(clk),
    .rstn(rstn),
    .i_ref_word_idx(i_ref_word_idx),
    .i_guess_word(i_guess_word),
    .i_guess_id(i_guess_id),
    .o_ready(o_ready),
    .o_result(o_result),
    .o_guess_count(o_guess_count),
    .o_game_status(o_game_status)
);

// This initial block generates a clock signal
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

/******* Your code starts here *******/
// Add any signal/variable declarations you need here.

//colour result for each letter
localparam logic [1:0] GREY = 2'b00;
localparam logic [1:0] GREEN = 2'b01;
localparam logic [1:0] YELLOW = 2'b10;

//game state
localparam logic [1:0] ONGOING = 2'b00;
localparam logic [1:0] LOSE = 2'b10;
localparam logic [1:0] WIN  = 2'b11;

//sending a guess of four letters
function automatic logic [WORD_WIDTH-1:0] pack4(
    input byte c0, input byte c1, input byte c2, input byte c3
);
    pack4 = {c0, c1, c2, c3};
endfunction

// shift to kind of deal with parsing
function automatic logic [1:0] res_at_c(input logic [RSLT_WIDTH-1:0] r, input int i);
    int sh;
    begin
        sh = 2*(NUM_LETTERS-1-i);
        res_at_c = (r >> sh) & 2'b11; //changed this line to fix rvrse
    end
endfunction

task automatic check_eq(input string msg, input logic cond); //check to see if rsult match
begin
    if (!cond) begin
        sim_failed = 1'b1;
        $display("FAIL: %s (t=%0t)", msg, $time);
    end else begin
        $display("PASS: %s (t=%0t)", msg, $time);
    end
end
endtask

task automatic wait_ready(input int unsigned max_cycles = 200); //wait for comp
    int unsigned cyc;
begin : WAIT_RDY
    cyc = 0;
    while (o_ready !== 1'b1) begin
        @(posedge clk);
        cyc++;
        if (cyc >= max_cycles) begin
            sim_failed = 1'b1;
            $display("FAIL: timeout waiting for o_ready (t=%0t)", $time); //debug statement
            disable WAIT_RDY;
        end
    end
end
endtask

//handle waits for guess
task automatic wait_done(input int unsigned max_cycles = 200);
    int unsigned cyc;
begin : WAIT_DONE
    cyc = 0;
    while (1) begin
        @(posedge clk);
        cyc++;

        if ((o_game_status === WIN) || (o_game_status === LOSE)) disable WAIT_DONE;
        if (o_ready === 1'b1) disable WAIT_DONE;

        if (cyc >= max_cycles) begin
            sim_failed = 1'b1;
            $display("FAIL: timeout waiting for guess to finish (t=%0t)", $time);
            disable WAIT_DONE;
        end
    end
end
endtask

task automatic send_guess( //send in usr guess
    input logic [WORD_WIDTH-1:0] w,
    input logic [GUESS_CNTW-1:0] gid
);
begin
    wait_ready();
    @(negedge clk);
    i_guess_word = w;//word that was guessed
    i_guess_id = gid; //id of the guess (to be compared?)
    @(posedge clk);
    wait_done();
end
endtask

task automatic start_new_game(input logic [ADDR_WIDTH-1:0] ref_idx);//reset state to js redo
begin
    @(negedge clk);
    i_ref_word_idx = ref_idx;
    i_guess_word  = '0;
    i_guess_id = '0;
    wait_ready();
end
endtask

/******* Your code ends here ********/

initial begin
    sim_failed = 1'b0;
    rstn = 1'b0;
    i_ref_word_idx = 'd0;
    i_guess_word = 'd0;
    i_guess_id = 'd0;
    prev_res = '0;
    prev_cnt = '0;

    #(5*CLK_PERIOD);
    
    rstn = 1'b1; //stop rst

    // test 1: straight up a DUB
    $display("\n=== TEST 1===");
    start_new_game('d0);
    send_guess(pack4("s","k","i","m"), 'd1);

    check_eq("WIN: game status == WIN", (o_game_status === WIN));
    check_eq("WIN: guess_count == 1", (o_guess_count === 'd1));
    
    //expected rslt: GGGG
    check_eq("WIN: char0==GREEN", (res_at_c(o_result,0) === GREEN));
    check_eq("WIN: char1==GREEN", (res_at_c(o_result,1) === GREEN));
    check_eq("WIN: char2==GREEN", (res_at_c(o_result,2) === GREEN));
    check_eq("WIN: char3==GREEN", (res_at_c(o_result,3) === GREEN));

    repeat (2) @(posedge clk);
    check_eq("After WIN: o_ready stays low", (o_ready === 1'b0));

    // test 2: 6 guess and done
    $display("\n=== TEST 2===");
    start_new_game('d79); //word is test -> all should be wrong but then reset

    send_guess(pack4("s","k","i","m"), 'd1);
    check_eq("After guess 1: status ongoing", (o_game_status === ONGOING));
    check_eq("After guess 1: count==1", (o_guess_count === 'd1));

    send_guess(pack4("s","k","a","m"), 'd2);
    check_eq("After guess 2: status ongoing", (o_game_status === ONGOING));
    check_eq("After guess 2: count==2", (o_guess_count === 'd2));

    send_guess(pack4("m","a","k","s"), 'd3);
    check_eq("After guess 3: status ongoing", (o_game_status === ONGOING));
    check_eq("After guess 3: count==3", (o_guess_count === 'd3));

    send_guess(pack4("s","k","i","m"), 'd4);
    check_eq("After guess 4: status ongoing", (o_game_status === ONGOING));
    check_eq("After guess 4: count==4", (o_guess_count === 'd4));

    send_guess(pack4("s","k","i","m"), 'd5);
    check_eq("After guess 5: status ongoing", (o_game_status === ONGOING));
    check_eq("After guess 5: count==5", (o_guess_count === 'd5));

    send_guess(pack4("s","k","i","m"), 'd6);
    check_eq("LOSE: game status == LOSE", (o_game_status === LOSE));
    check_eq("LOSE: guess_count == 6", (o_guess_count === 'd6));
    check_eq("After LOSE: o_ready stays low", (o_ready === 1'b0)); //waiting for signal cause you lost

    //test 3: go back to init/reset state -> shld rst main vals
    $display("\n=== TEST 3===");
    start_new_game('d3);//word corn

    send_guess(pack4("c","o","r","n"), 'd1);
    check_eq("Restart WIN: status == WIN", (o_game_status === WIN));
    check_eq("Restart WIN: guess_count == 1", (o_guess_count === 'd1));

    // test 4: if same id is used -> checks if curr id is bigger then prev id
    $display("\n=== TEST 4===");
    start_new_game('d0);

    send_guess(pack4("a","b","c","d"), 'd1);
    prev_res = o_result; //prev result
    prev_cnt = o_guess_count; 

    // same guess_id again -> ignore it
    @(negedge clk);
    i_guess_word = pack4("d","c","b","a");
    i_guess_id   = 'd1;
    @(posedge clk);
    repeat (10) @(posedge clk);

    check_eq("Same guess_id ignored: result stable", (o_result === prev_res));
    check_eq("Same guess_id ignored: count stable", (o_guess_count === prev_cnt));
    
    send_guess(pack4("d","c","b","a"), 'd2);// new id processes
    check_eq("New guess_id increments count==2", (o_guess_count === 'd2));
    
    //test 5: flip flop
    $display("\n=== TEST 5===");
    send_guess(pack4("s","i","k","i"), 'd3);
    
    //should be GXYY  
    check_eq("T5-A: char0 GREEN", (res_at_c(o_result,0) === GREEN));
    check_eq("T5-A: char1 GREY",  (res_at_c(o_result,1) === GREY));
    check_eq("T5-A: char2 YELLOW",  (res_at_c(o_result,2) === YELLOW));
    check_eq("T5-A: char3 YELLOW",  (res_at_c(o_result,3) === YELLOW));
    
    //GYXY
    send_guess(pack4("s","i","x","k"), 'd4);
    
    check_eq("T5-B: char0 GREEN",  (res_at_c(o_result,0) === GREEN));
    check_eq("T5-B: char1 YELLOW",  (res_at_c(o_result,1) === YELLOW));
    check_eq("T5-B: char2 GREY",  (res_at_c(o_result,2) === GREY));
    check_eq("T5-B: char3 YELLOW", (res_at_c(o_result,3) === YELLOW));
    
    //XXGX
    send_guess(pack4("i","i","i","i"), 'd5);
    
    check_eq("T5-B: char0 GREY",  (res_at_c(o_result,0) === GREY));
    check_eq("T5-B: char1 GREY",  (res_at_c(o_result,1) === GREY));
    check_eq("T5-B: char2 GREEN",  (res_at_c(o_result,2) === GREEN));
    check_eq("T5-B: char3 GREY", (res_at_c(o_result,3) === GREY));
    
    //test 6: forcefully set to init -> test new cases lol
    $display("\n=== TEST 6===");
    // HARD RESET so we are guaranteed to be in ST_INIT (since start_new_game only works after WIN/LOSE)
    rstn = 1'b0;
    repeat (5) @(posedge clk);
    rstn = 1'b1;

    start_new_game('d0); //skim is the word

    send_guess(pack4("z","z","z","z"), 'd1);

    check_eq("T6: status ongoing", (o_game_status === ONGOING));
    check_eq("T6: guess_count == 1", (o_guess_count === 'd1));
    
    // should be XXXX
    check_eq("T6: char0 GREY", (res_at_c(o_result,0) === GREY));
    check_eq("T6: char1 GREY", (res_at_c(o_result,1) === GREY));
    check_eq("T6: char2 GREY", (res_at_c(o_result,2) === GREY));
    check_eq("T6: char3 GREY", (res_at_c(o_result,3) === GREY));

    //test 7: doubel letter type shi
    $display("\n=== TEST 7===");
    rstn = 1'b0; //hard reset so we can start again
    repeat (5) @(posedge clk);
    rstn = 1'b1;

    start_new_game('d0); //skim

    send_guess(pack4("x","x","i","i"), 'd1);

    check_eq("T7: status ongoing", (o_game_status === ONGOING));
    check_eq("T7: guess_count == 1", (o_guess_count === 'd1));

    check_eq("T7: char0 GREY",   (res_at_c(o_result,0) === GREY));
    check_eq("T7: char1 GREY",   (res_at_c(o_result,1) === GREY));
    check_eq("T7: char2 GREEN",  (res_at_c(o_result,2) === GREEN)); //continuously fails!!
    check_eq("T7: char3 YELLOW", (res_at_c(o_result,3) === GREY));
    
    //test 8: 6 guesses again cause it was finiicky on the board
    $display("\n=== TEST 11: Exact 6 guesses (no early win) ===");
    start_new_game('d9); // choose reference word, e.g., "corn"

    // Make 6 incorrect guesses
    send_guess(pack4("a","b","c","d"), 'd1); 
    check_eq("T11: After guess 1: status ongoing", (o_game_status === ONGOING));
    check_eq("T11: count==1", (o_guess_count === 'd1));
    
    send_guess(pack4("e","f","g","h"), 'd2); 
    check_eq("T11: After guess 2: status ongoing", (o_game_status === ONGOING));
    check_eq("T11: count==2", (o_guess_count === 'd2));
    
    send_guess(pack4("i","j","k","l"), 'd3); 
    check_eq("T11: After guess 3: status ongoing", (o_game_status === ONGOING));
    check_eq("T11: count==3", (o_guess_count === 'd3));
    
    send_guess(pack4("m","n","o","p"), 'd4); 
    check_eq("T11: After guess 4: status ongoing", (o_game_status === ONGOING));
    check_eq("T11: count==4", (o_guess_count === 'd4));
    
    send_guess(pack4("q","r","s","t"), 'd5); 
    check_eq("T11: After guess 5: status ongoing", (o_game_status === ONGOING));
    check_eq("T11: count==5", (o_guess_count === 'd5));
    
    send_guess(pack4("u","v","w","x"), 'd6); 
    check_eq("T11: After guess 6: status LOSE", (o_game_status === LOSE));
    check_eq("T11: count==6", (o_guess_count === 'd6));
    
    if (sim_failed) begin
        $display("TEST FAILED!");
    end else begin            
        $display("TEST PASSED!");
    end
    $stop;
end

endmodule
