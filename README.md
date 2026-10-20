# Interton VC 4000 for Analogue Pocket

An openFPGA core for the Analogue Pocket that recreates the Interton VC 4000,
a European console from 1978 built around the Signetics 2650 CPU and 2636
video chip. It also plays games for the compatible consoles that used the same
chips, such as the Acetronic MPU-1000 and Occitane OC2000. It is a port of
the [MiSTer VC4000 core](https://github.com/MiSTer-devel/VC4000_MiSTer).

**Status: early test build (0.1.0).** Tested in simulation and on a Pocket
with Super Invaders (picture, controls and sound).

## Installing

1. Download the latest release zip and copy its contents to the root of your
   Pocket's SD card.
2. Put your cartridge images (`.bin`, up to 8 KB) in `Assets/vc4000/common/`
   (or any subfolder). No BIOS is needed.

## Controls

| Pocket | VC 4000 |
|---|---|
| D-pad | Joystick |
| A | Fire (keypad 2) |
| B / X / Y | Keypad 1 / 3 / 0 |
| L / R | Clear / Enter |
| Start | Start |
| Select (tap) | Game Select |
| Hold Select + X / Y / A / B | Keypad 4 / 5 / 6 / 7 |
| Hold Select + Up / Right | Keypad 8 / 9 |
| Dock L2 | Game Select |

Two controllers work in the Dock. The original joysticks are analog: a Dock
controller's left analog stick works as one, and the core switches between it
and the D-pad by itself.

## Settings (Core Settings menu)

* **Reset**: restarts the game.
* **Swap Controllers 1+2**
* **D-Pad Mode**: *Absolute* moves the joystick straight to its edge while a
  direction is held (like the MiSTer core); *Gradual* moves it step by step,
  which suits games that expect a stick held part way.
* **Bright Colours**: draws objects and the score at full brightness.

## Speed

The core runs at the original PAL console's speed: 50 Hz, with an 886.7 kHz
CPU (the clocks MAME uses). The MiSTer core runs about 25% faster than that.

## How the port works

On MiSTer, the ARM processor streams the cartridge into the core, which keeps
it in a writable array together with the console's RAM. The Pocket has no such
processor, so:

* `src/fpga/core/pocket/cart_loader.v` receives the cartridge from the Pocket
  into a small buffer.
* `src/fpga/core/pocket/boot_seq.v` resets the console, copies all 8 KB of
  cartridge space into the core (zeros past the end of the file, so nothing is
  left over from a previous game) and starts the CPU. The Reset setting does
  the same again.
* `input_map.v`, `video_apf.v` and `audio_apf.v` adapt the controllers, video
  and sound to the Pocket. The top three lines of the picture are hidden:
  nothing can legitimately start there, but the core draws one stale sprite
  line on the first line when a game moves a sprite away from an off-screen
  position (a flickering line at the top). On a TV those lines are in the
  overscan.
* The console itself (`src/fpga/core/vc4000/`) is an unchanged copy of the
  MiSTer core (commit `2d12fc0`).

## Building

The GitHub Actions workflow builds the core with Quartus Prime Lite 21.1 in
Docker and uploads an SD card ready zip. Publishing a release tagged
`v<version>` (matching `core.json`) attaches the zip to the release. To build
locally, open `src/fpga/ap_core.qpf` in Quartus Prime Lite, compile, then run
`python3 tools/package.py` to create `release/sd/`.

## Simulation

`sim/` runs the whole core with GHDL and Verilator, loading a cartridge over a
simulated Pocket bridge and saving every frame as an image. The tests use a
small cartridge written for them (`sim/make_test_cart.py`), so no game ROMs
are needed:

```
cd sim
./build.sh
./run_tests.sh
```

They check the picture size and the Pocket's video rules, every button and the
Select shift, controller swapping, reloading a smaller cartridge, the Reset and
Bright Colours settings, the sound output, and that no stale sprite line shows
at the top of the picture.

## Credits and licence

* VC4000 FPGA core (2650 CPU, 2636 video chip): TEMLIB, for MiSTer
* Pocket port: this repository
* Audio I2S and helper design based on Analogue's openFPGA core template and
  Adam Gastineau's analogue-pocket-utils (MIT)

Released under the GNU GPL v2 (see `LICENSE`), like the MiSTer VC4000 core.
The files in `src/fpga/apf/` are Analogue's openFPGA framework.

This core does not include any game ROMs.
