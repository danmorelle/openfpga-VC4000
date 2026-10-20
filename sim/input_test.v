//
// Unit test for input_map.v: every button, the Select shift and tap,
// analog sticks and controller swapping.
//
//   iverilog -g2012 -o out/input_test.vvp input_test.v ../src/fpga/core/pocket/input_map.v
//   vvp out/input_test.vvp
//

`timescale 1ns/1ps

module input_test;
  reg clk = 0;
  always #5 clk = ~clk;

  reg  [31:0] k1 = 0, k2 = 0, j1 = 32'h80808080, j2 = 32'h80808080;
  reg         swap = 0;
  wire [31:0] joy0, joy1;
  wire [15:0] an0, an1;

  input_map dut (.clk(clk), .cont1_key(k1), .cont2_key(k2), .cont1_joy(j1), .cont2_joy(j2),
                 .swap12(swap), .joystick_0(joy0), .joystick_1(joy1), .analog_0(an0), .analog_1(an1));
  defparam dut.m1.SELECT_CYCLES = 22'd20;
  defparam dut.m2.SELECT_CYCLES = 22'd20;

  // Pocket key bits
  localparam UP = 0, DOWN = 1, LEFT = 2, RIGHT = 3, A = 4, B = 5, X = 6, Y = 7,
             L1 = 8, R1 = 9, L2 = 10, R2 = 11, SEL = 14, START = 15;

  integer errors = 0, checks = 0;

  task check(input [31:0] got, input [31:0] expv, input [8*40-1:0] what);
    begin
      checks = checks + 1;
      if (got !== expv) begin
        errors = errors + 1;
        $display("FAIL %0s: got %08x expected %08x", what, got, expv);
      end
    end
  endtask

  task press(input [31:0] keys, input [31:0] expv, input [8*40-1:0] what);
    begin
      k1 = keys;
      repeat (2) @(posedge clk);
      check(joy0, expv, what);
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    // direct buttons
    press(1 << UP,    1 << 3,  "up");
    press(1 << DOWN,  1 << 2,  "down");
    press(1 << LEFT,  1 << 1,  "left");
    press(1 << RIGHT, 1 << 0,  "right");
    press(1 << A,     1 << 7,  "A = key 2 / fire");
    press(1 << B,     1 << 6,  "B = key 1");
    press(1 << X,     1 << 8,  "X = key 3");
    press(1 << Y,     1 << 16, "Y = key 0");
    press(1 << L1,    1 << 17, "L = Clear");
    press(1 << R1,    1 << 15, "R = Enter");
    press(1 << START, 1 << 5,  "Start");
    press(1 << L2,    1 << 4,  "Dock L2 = Game Select");
    press(1 << R2,    0,       "Dock R2 unused");
    press(0, 0, "release");

    // Select held as shift: keys 4..9, other buttons silent
    press((1 << SEL) | (1 << X),     1 << 9,  "Select+X = 4");
    press((1 << SEL) | (1 << Y),     1 << 10, "Select+Y = 5");
    press((1 << SEL) | (1 << A),     1 << 11, "Select+A = 6");
    press((1 << SEL) | (1 << B),     1 << 12, "Select+B = 7");
    press((1 << SEL) | (1 << UP),    1 << 13, "Select+Up = 8");
    press((1 << SEL) | (1 << RIGHT), 1 << 14, "Select+Right = 9");
    press((1 << SEL) | (1 << DOWN),  0,       "Select+Down silent");
    press((1 << SEL) | (1 << START), 0,       "Select+Start silent");
    // releasing after a combination must not send Game Select
    press(0, 0, "no Game Select after a combination");
    repeat (5) @(posedge clk);
    check(joy0, 0, "still no Game Select");

    // Select tapped alone: Game Select for SELECT_CYCLES clocks
    press(1 << SEL, 0, "Select down: nothing yet");
    press(0, 1 << 4, "Select tap = Game Select");
    repeat (25) @(posedge clk);
    check(joy0, 0, "Game Select pulse ends");

    // analog: only for Dock controllers that report analog sticks
    k1 = 32'h1000_0000; j1 = 32'h0000_FF00;      // Pocket: ignored
    repeat (2) @(posedge clk);
    check({16'd0, an0}, 0, "Pocket has no analog");
    k1 = 32'h3000_0000;                          // Dock analog
    repeat (2) @(posedge clk);
    check({16'd0, an0}, 32'h0000_7F80, "analog: x left, y down (full)");
    j1 = 32'h0000_8080;
    repeat (2) @(posedge clk);
    check({16'd0, an0}, 0, "analog centre");
    j1 = 32'h0000_C040;
    repeat (2) @(posedge clk);
    check({16'd0, an0}, 32'h0000_40C0, "analog: x left, y down (half)");

    // swap controllers
    k1 = 32'h3000_0000 | (1 << A); k2 = 1 << B; swap = 1;
    repeat (2) @(posedge clk);
    check(joy0, 1 << 6, "swap: player 1 gets controller 2");
    check(joy1, 1 << 7, "swap: player 2 gets controller 1");
    check({16'd0, an1}, 32'h0000_40C0, "swap: analog follows");
    swap = 0;
    repeat (2) @(posedge clk);
    check(joy0, 32'h0000_0080, "no swap");

    $display("input_test: %0d checks, %0d errors", checks, errors);
    $finish;
  end
endmodule
