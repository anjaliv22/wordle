# Wordle in Hardware

**full code has not been disclosed, but this is the main working logic we built!!

A hardware version of Wordle written in SystemVerilog, built with a partner. It runs on an AMD/Xilinx Kria KV260 FPGA board.

## How it works

- Words are 4 letters long and you get 6 guesses.
- The game logic is a finite state machine (FSM) with 4 states:
  - **INIT:** loads the secret word and resets the guess count and status
  - **WAIT:** waits for a new guess (only accepts a guess if its ID is higher than the last one, so the same guess isn't counted twice)
  - **PROCESS:** compares each letter and marks it **green** (right letter, right spot), **yellow** (right letter, wrong spot) or **grey** (not in the word)
  - **STATUS:** checks if you won, lost, or the game keeps going
- Repeated letters are handled correctly: a letter is only marked yellow if there's an unused matching letter left in the secret word.

## Files

| File | What's in it |
|---|---|
| `wordle_fsm.sv` | The Wordle game FSM |
| `wordle_top_tb.sv` | Testbench |

## What I learned

- Designing an FSM with separate state registers and next-state logic
- Writing a self-checking testbench in SystemVerilog
- Handling tricky cases like repeated letters in hardware
- Testing a design in simulation and then on a real FPGA board
