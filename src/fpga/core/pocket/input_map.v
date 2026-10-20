//
// Pocket / Dock controllers -> VC 4000 controllers
//
// Output layout is the MiSTer core's joystick word (active high):
//   0 right, 1 left, 2 down, 3 up, 4 Game Select, 5 Start,
//   6 key 1, 7 key 2 (also the fire button), 8 key 3,
//   9 key 4, 10 key 5, 11 key 6, 12 key 7, 13 key 8, 14 key 9,
//   15 Enter, 16 key 0, 17 Clear
// (checked against the keypad matrix in vc4000_core.vhd and MAME's
// vc4000 driver: 0x1E88-0x1E8A hold the keys 1/4/7/Enter, 2/5/8/0 and
// 3/6/9/Clear; 0x1E8B bit 7 is Game Select and bit 6 is Start.)
//
// Button layout (Pocket or Dock controller):
//   A = Fire (key 2)   B = key 1   X = key 3   Y = key 0
//   L = Clear          R = Enter   Start = Start
//   Select tapped on its own = Game Select
//   Select held as a shift key:
//     X = 4   Y = 5   A = 6   B = 7   Up = 8   Right = 9
//   Dock extra: L2 = Game Select
//
// The original controllers have analog joysticks. A Dock controller's
// left analog stick is passed through; the core switches between it
// and the D-pad by itself.
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

`default_nettype none

module pad_map #(
    parameter SELECT_CYCLES = 22'd2837500   // ~100 ms at 28.375 MHz
) (
    input  wire        clk,
    input  wire [31:0] key,
    input  wire [31:0] joy,

    output reg  [31:0] j,
    output wire [15:0] analog                 // {Y, X}, signed
);

  wire up    = key[0];
  wire down  = key[1];
  wire left  = key[2];
  wire right = key[3];
  wire a     = key[4];
  wire b     = key[5];
  wire x     = key[6];
  wire y     = key[7];
  wire l1    = key[8];
  wire r1    = key[9];
  wire l2    = key[10];
  wire sel   = key[14];
  wire start = key[15];

  wire is_analog = (key[31:28] == 4'h3);

  // ---- Select: tap for Game Select, hold as shift ----
  reg        sel_prev = 0;
  reg        sel_used = 0;
  reg [21:0] select_cnt = 0;

  wire others = up | down | left | right | a | b | x | y | l1 | r1 | start;

  always @(posedge clk) begin
    sel_prev <= sel;
    if (sel & ~sel_prev) sel_used <= 0;
    else if (sel & others) sel_used <= 1;

    if (~sel & sel_prev & ~sel_used) select_cnt <= SELECT_CYCLES;
    else if (select_cnt != 0) select_cnt <= select_cnt - 1'd1;
  end

  wire shift = sel;

  always @(*) begin
    j = 32'd0;
    if (!shift) begin
      j[0]  = right;
      j[1]  = left;
      j[2]  = down;
      j[3]  = up;
      j[5]  = start;       // Start
      j[7]  = a;           // 2 / Fire
      j[6]  = b;           // 1
      j[8]  = x;           // 3
      j[16] = y;           // 0
      j[17] = l1;          // Clear
      j[15] = r1;          // Enter
    end else begin
      j[9]  = x;           // 4
      j[10] = y;           // 5
      j[11] = a;           // 6
      j[12] = b;           // 7
      j[13] = up;          // 8
      j[14] = right;       // 9
    end
    j[4] = (select_cnt != 0) | l2;   // Game Select
  end

  // Pocket sticks are unsigned with 0x80 at the centre; the core wants
  // signed values. Only Dock controllers that report analog sticks.
  assign analog = is_analog ? {joy[15] ^ 1'b1, joy[14:8], joy[7] ^ 1'b1, joy[6:0]} : 16'd0;

endmodule


module input_map (
    input  wire        clk,
    input  wire [31:0] cont1_key, cont2_key,
    input  wire [31:0] cont1_joy, cont2_joy,
    input  wire        swap12,

    output wire [31:0] joystick_0, joystick_1,
    output wire [15:0] analog_0, analog_1
);

  wire [31:0] p1, p2;
  wire [15:0] a1, a2;

  pad_map m1 (.clk(clk), .key(cont1_key), .joy(cont1_joy), .j(p1), .analog(a1));
  pad_map m2 (.clk(clk), .key(cont2_key), .joy(cont2_joy), .j(p2), .analog(a2));

  assign joystick_0 = swap12 ? p2 : p1;
  assign joystick_1 = swap12 ? p1 : p2;
  assign analog_0   = swap12 ? a2 : a1;
  assign analog_1   = swap12 ? a1 : a2;

endmodule
