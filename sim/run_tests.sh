#!/bin/bash
# Whole-core tests with the generated test cartridge (no commercial ROMs):
#   * picture size and the APF video protocol
#   * every kind of button press reaches the console
#   * reloading a smaller cartridge clears what the bigger one left behind
#   * the Reset and Bright settings, controller swapping, sound
set -e
cd "$(dirname "$0")"
mkdir -p roms out
python3 make_test_cart.py roms/test.bin > /dev/null
python3 make_test_cart.py roms/test2k.bin --2k > /dev/null
python3 make_test_cart.py roms/sprite.bin --sprite > /dev/null
[ -x obj_dir/Vtb_top ] || ./build.sh > /dev/null

fail=0
expect() {   # log frame colour description
  local got
  got=$(grep -o "frame $2: .*centre=[0-9a-f]*" "$1" | grep -o "centre=[0-9a-f]*" | cut -d= -f2)
  if [ "$got" == "$3" ]; then echo "PASS $4"; else echo "FAIL $4 (frame $2: $got, want $3)"; fail=1; fi
}
expect_line() {   # log pattern description
  if grep -q "$2" "$1"; then echo "PASS $3"; else echo "FAIL $3"; fail=1; fi
}

RED=7f0000 GREEN=007f00 BLUE=00007f MAGENTA=7f007f CYAN=007f7f YELLOW=7f7f00

# Pocket key bits: A 0x10, Y 0x80, L 0x100, Select 0x4000, Start 0x8000
./obj_dir/Vtb_top +frames=32 +out=out/keys \
  +press0=2,2,10 +press1=6,2,8000 +press2=10,1,4000 +press3=18,3,4080 \
  +press4=24,2,100 +press5=28,2,4010 > out/keys.log 2>&1
expect_line out/keys.log "frame 0: hs=312 de_lines=266 width min=172 max=172" "picture is 172 x 266, 312 lines"
expect_line out/keys.log "APF video protocol errors: 0" "APF video protocol"
expect out/keys.log 1  $RED     "nothing pressed"
expect out/keys.log 3  $GREEN   "A = fire (key 2)"
expect out/keys.log 7  $BLUE    "Start"
expect out/keys.log 10 $RED     "Select held: no Game Select yet"
expect out/keys.log 13 $MAGENTA "Select tap = Game Select"
expect out/keys.log 17 $RED     "Game Select pulse ends"
expect out/keys.log 19 $CYAN    "Select+Y = key 5"
expect out/keys.log 22 $RED     "no Game Select after a combination"
expect out/keys.log 25 $YELLOW  "L = Clear"
expect out/keys.log 29 $RED     "Select+A = key 6, not fire"
if grep -q "rgb not zero outside de" out/keys.log; then echo "FAIL rgb outside DE"; fail=1; else echo "PASS rgb zero outside DE"; fi
changes=$(grep -o "sound output changes: [0-9]*" out/keys.log | grep -o "[0-9]*$")
if [ "$changes" -gt 50 ]; then echo "PASS tone generator ($changes edges)"; else echo "FAIL tone generator"; fail=1; fi

./obj_dir/Vtb_top +frames=5 +out=out/swap +swap=1 +press0=2,3,10 > out/swap.log 2>&1
expect out/swap.log 3 $RED "swapped: controller 1 is player 2"

./obj_dir/Vtb_top +frames=9 +out=out/reload +reload=3,roms/test2k.bin \
  +poke=6,4000000C,1 +poke2=7,40000000,1 > out/reload.log 2>&1
expect_line out/reload.log "loader size_words=512" "reload: 2 KB cartridge loaded"
expect_line out/reload.log "\[frame 7\] core running" "Reset restarts the core"
python3 - <<'EOF' || fail=1
from PIL import Image
import sys
def digits(f):
    im = Image.open(f'out/reload_{f:03d}.ppm').convert('RGB')
    # digit 3 of the score: lit pixels in its box mean a non-zero glyph
    # differs from "0"; compare against the frame shown after the reload
    return [im.getpixel((x, y)) for y in range(20, 42) for x in range(98, 130)]
before, after = digits(2), digits(5)
ok = True
if before == after:
    print('FAIL reload: score digits 3-4 unchanged (leftover data not cleared)'); ok = False
else:
    print('PASS reload clears data past the end of the smaller file')
im = Image.open('out/reload_008.ppm').convert('RGB')
lit = [im.getpixel((x, y)) for y in range(20, 42) for x in range(50, 130)]
if (255, 255, 255) in lit:
    print('PASS Bright setting (score drawn at full brightness)')
else:
    print('FAIL Bright setting'); ok = False
sys.exit(0 if ok else 1)
EOF

# A sprite moved away from an off-screen position must not leave a line
# at the top of the next frame
./obj_dir/Vtb_top +cart=roms/sprite.bin +frames=6 +out=out/sprite > out/sprite.log 2>&1
python3 - <<'EOF' || fail=1
from PIL import Image
import sys
ok = True
seen = 0
for f in range(1, 6):
    im = Image.open(f'out/sprite_{f:03d}.ppm').convert('RGB')
    w, h = im.size
    white = lambda y: any(im.getpixel((x, y))[0] > 100 for x in range(w))
    if white(129):                      # sprite at VC 0x80 this frame (lines 128-137)
        seen += 1
        if any(white(y) for y in range(0, 4)):
            print(f'FAIL stale sprite line at the top (frame {f})'); ok = False
if seen == 0:
    print('FAIL sprite test did not run'); ok = False
elif ok:
    print(f'PASS no stale sprite line at the top ({seen} frames checked)')
sys.exit(0 if ok else 1)
EOF

iverilog -g2012 -o out/input_test.vvp input_test.v ../src/fpga/core/pocket/input_map.v
res=$(vvp out/input_test.vvp | grep "input_test:")
echo "$res"
echo "$res" | grep -q ", 0 errors" || fail=1

if [ $fail == 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; exit 1; fi
