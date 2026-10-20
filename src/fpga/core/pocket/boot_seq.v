//
// VC 4000 boot sequence for the Analogue Pocket
//
// On MiSTer the ARM streams the cartridge into the core through the
// ioctl download port, which also holds the CPU in reset. Here the
// cartridge first lands in cart_loader's buffer while the Pocket holds
// the core in reset; once the Pocket lets go, this block:
//
//   1. resets the whole core (CPU, video chip, sound) for a moment,
//   2. copies all 8 KB of cartridge space into the core through the same
//      download port, with zeros past the end of the file (so RAM and
//      any part of a larger previous game are cleared), and
//   3. lets the CPU run.
//
// The Reset setting repeats steps 1 to 3, which also restores the
// cartridge image (the core keeps ROM and RAM in one writable array).
//
// SPDX-License-Identifier: GPL-2.0-or-later
//

`default_nettype none

module boot_seq (
    input  wire        clk,
    input  wire        run_ok,          // Pocket has finished loading
    input  wire        reset_req,       // one clock pulse: restart the game
    input  wire [11:0] size_words,      // cartridge size, static while used

    output reg  [12:0] buf_addr = 0,    // cart_loader read address
    input  wire [7:0]  buf_data,        // ... data one clock later

    output reg         core_reset = 1,  // with download: full reset
    output reg         download   = 1,  // holds the CPU in reset
    output reg         ioctl_wr   = 0,
    output reg  [12:0] ioctl_addr = 0,
    output reg  [7:0]  ioctl_dout = 0,
    output reg         running    = 0
);

  localparam S_HOLD  = 2'd0;
  localparam S_RESET = 2'd1;
  localparam S_COPY  = 2'd2;
  localparam S_RUN   = 2'd3;

  reg [1:0]  state = S_HOLD;
  reg [7:0]  count = 0;
  reg        rd_valid = 0;
  reg [12:0] rd_addr_d = 0;
  reg        last = 0;

  wire [13:0] size_bytes = {size_words, 2'b00};

  always @(posedge clk) begin
    ioctl_wr <= 0;

    // Write the byte read on the previous clock
    rd_valid  <= 0;
    if (rd_valid) begin
      ioctl_wr   <= 1;
      ioctl_addr <= rd_addr_d;
      ioctl_dout <= ({1'b0, rd_addr_d} < size_bytes) ? buf_data : 8'h00;
    end

    case (state)
      S_HOLD: begin
        core_reset <= 1;
        download   <= 1;
        running    <= 0;
        if (run_ok) begin
          state <= S_RESET;
          count <= 0;
        end
      end

      S_RESET: begin
        core_reset <= 1;
        download   <= 1;
        running    <= 0;
        count      <= count + 1'd1;
        if (count == 8'hFF) begin
          state    <= S_COPY;
          buf_addr <= 0;
          last     <= 0;
        end
      end

      S_COPY: begin
        core_reset <= 0;
        download   <= 1;
        if (!last) begin
          rd_valid  <= 1;
          rd_addr_d <= buf_addr;
          buf_addr  <= buf_addr + 1'd1;
          if (buf_addr == 13'h1FFF) begin
            last  <= 1;
            count <= 0;
          end
        end else begin
          // let the last writes reach the cartridge RAM
          count <= count + 1'd1;
          if (count == 8'd15) state <= S_RUN;
        end
      end

      S_RUN: begin
        core_reset <= 0;
        download   <= 0;
        running    <= 1;
        if (reset_req) begin
          state <= S_RESET;
          count <= 0;
        end
      end
    endcase

    if (!run_ok) state <= S_HOLD;
  end

endmodule
