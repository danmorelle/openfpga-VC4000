//
// Clock generation for the VC 4000 core
//
//   outclk_0  28.375 MHz  core clock (8 x the 3.546875 MHz PAL pixel clock)
//   outclk_1  28.375 MHz  same, 90 degrees shifted (APF video_rgb_clock_90)
//
// 28.375 MHz gives the original PAL console's timing: a 3.546875 MHz
// pixel clock, 15.625 kHz lines, 50 Hz frames and an 886.7 kHz CPU (the
// same clocks MAME uses). MiSTer runs the core at 35.469 MHz instead,
// which is about 25% faster than a real console.
//
// Reference: clk_74a (74.25 MHz). Fractional PLL.
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

`timescale 1ns/10ps

module pll_vc4000 (
    input  wire refclk,
    input  wire rst,
    output wire outclk_0,
    output wire outclk_1,
    output wire locked
);

  altera_pll #(
      .fractional_vco_multiplier("true"),
      .reference_clock_frequency("74.25 MHz"),
      .operation_mode("direct"),
      .number_of_clocks(2),
      .output_clock_frequency0("28.375000 MHz"),
      .phase_shift0("0 ps"),
      .duty_cycle0(50),
      .output_clock_frequency1("28.375000 MHz"),
      .phase_shift1("8811 ps"),
      .duty_cycle1(50),
      .pll_type("General"),
      .pll_subtype("General")
  ) altera_pll_i (
      .rst     (rst),
      .outclk  ({outclk_1, outclk_0}),
      .locked  (locked),
      .fboutclk(),
      .fbclk   (1'b0),
      .refclk  (refclk)
  );

endmodule
