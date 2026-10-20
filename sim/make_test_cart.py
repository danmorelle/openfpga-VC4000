#!/usr/bin/env python3
"""Build a small VC 4000 test cartridge (Signetics 2650 machine code).

The program shows the score digits 1 2 3 4 at the top of the screen and
sets the screen colour from the controls, so a simulation can check the
whole path from the Pocket buttons to the picture:

    nothing pressed      red    (colour 4)
    Start                blue   (colour 1)
    Game Select          magenta(colour 5)
    key 2 / fire         green  (colour 2)
    key 5                cyan   (colour 3)
    Clear                yellow (colour 6)

It also turns the tone generator on, so the sound output can be checked,
and shows the byte at 0x0FFF as score digits 3 and 4. The 4 KB cartridge
has 0x56 there, the 2 KB one (--2k) ends before it, so after loading the
4 KB cartridge and then the 2 KB one the digits must read 00 (the loader
clears everything past the end of the file).
No commercial ROM is needed.

--sprite builds a different cartridge instead: one solid sprite that jumps
between VC 0x80 and the off-screen position 0xFD on alternate frames. The
video chip then draws one stale sprite line at the very top of the next
frame (the flickering line seen on hardware), which the Pocket wrapper
must hide.

usage: make_test_cart.py <out.bin> [--2k | --sprite]
"""
import sys

PVI_SCORE12 = 0x1FC8
PVI_SCORE34 = 0x1FC9
PVI_SCOREFMT = 0x1FC3
PVI_COLOUR = 0x1FC6
PVI_SOUND = 0x1FC7
KEY_COL1 = 0x1E88   # bit 7 key 1, 6 key 4, 5 key 7, 4 Enter
KEY_COL2 = 0x1E89   # bit 7 key 2 (fire), 6 key 5, 5 key 8, 4 key 0
KEY_COL3 = 0x1E8A   # bit 7 key 3, 6 key 6, 5 key 9, 4 Clear
KEY_PANEL = 0x1E8B  # bit 7 Game Select, 6 Start
VOLNOISE = 0x1E80   # bit 2 tone on, bits 7:6 volume


class Asm:
    def __init__(self):
        self.code = {}
        self.pc = 0
        self.labels = {}
        self.fixups = []

    def org(self, a):
        self.pc = a

    def label(self, name):
        self.labels[name] = self.pc

    def emit(self, *bs):
        for b in bs:
            self.code[self.pc] = b & 0xFF
            self.pc += 1

    def abs_(self, op, addr):          # 3 byte absolute (page 0, no index)
        self.emit(op, (addr >> 8) & 0x1F, addr & 0xFF)

    def lodi(self, v):  self.emit(0x04, v)
    def andi(self, v):  self.emit(0x44, v)
    def loda(self, a):  self.abs_(0x0C, a)
    def stra(self, a):  self.abs_(0xCC, a)
    def ppsu(self, v):  self.emit(0x76, v)
    def rete(self):     self.emit(0x37)

    def bcta(self, label):             # unconditional absolute branch
        self.fixups.append(('abs', self.pc + 1, label))
        self.emit(0x1F, 0, 0)

    def bctr(self, cc, label):         # cc: 0 '=' 1 '>' 2 '<' 3 always
        self.fixups.append(('rel', self.pc + 1, label))
        self.emit(0x18 | cc, 0)

    def build(self, size):
        for kind, at, label in self.fixups:
            t = self.labels[label]
            if kind == 'abs':
                self.code[at] = (t >> 8) & 0x7F
                self.code[at + 1] = t & 0xFF
            else:
                d = t - (at + 1)       # relative to the next instruction
                assert -64 <= d <= 63, (label, d)
                self.code[at] = d & 0x7F
        out = bytearray(size)
        for a, b in self.code.items():
            out[a] = b
        return bytes(out)


def sprite_cart():
    a = Asm()
    a.org(0x0000)
    a.bcta('start')
    a.org(0x0003)
    a.rete()
    a.org(0x0010)
    a.label('start')
    a.ppsu(0x20)                       # inhibit interrupts
    for i in range(10):
        a.lodi(0xFF); a.stra(0x1F00 + i)   # object 1 shape: solid
    a.lodi(0x40); a.stra(0x1F0A); a.stra(0x1F0B)   # HC, HCB
    a.lodi(0x80); a.stra(0x1F0D)       # VCB
    a.lodi(0x00); a.stra(0x1FC0)       # object sizes
    a.lodi(0x00); a.stra(0x1FC1)       # object 1 white
    a.lodi(0x01); a.stra(PVI_COLOUR)   # screen blue
    a.emit(0x05, 0x00)                 # LODI,R1 0
    a.label('loop')
    a.label('w1')
    a.emit(0xB4, 0x80)                 # TPSU sense: wait for vertical reset
    a.bctr(2, 'w1')
    a.emit(0x25, 0x01)                 # EORI,R1 1
    a.bctr(0, 'park')
    a.lodi(0x80)
    a.bcta('store')
    a.label('park')
    a.lodi(0xFD)
    a.label('store')
    a.stra(0x1F0C)                     # VC
    a.label('w0')
    a.emit(0xB4, 0x80)                 # wait for vertical reset to end
    a.bctr(0, 'w0')
    a.bcta('loop')
    return a


def main():
    if '--sprite' in sys.argv:
        a = sprite_cart()
        data = a.build(2048)
        args = [x for x in sys.argv[1:] if not x.startswith('--')]
        out = args[0] if args else 'roms/sprite.bin'
        open(out, 'wb').write(data)
        print(f'{out}: {len(data)} bytes, program ends at {a.pc:#06x}')
        return

    a = Asm()
    a.org(0x0000)
    a.bcta('start')
    a.org(0x0003)                      # interrupt vector (PVI uses 0x03)
    a.rete()

    a.org(0x0010)
    a.label('start')
    a.ppsu(0x20)                       # inhibit interrupts
    a.lodi(0x12); a.stra(PVI_SCORE12)
    a.loda(0x0FFF); a.stra(PVI_SCORE34)
    a.lodi(0x00); a.stra(PVI_SCOREFMT) # score at the top
    a.lodi(0x40); a.stra(PVI_SOUND)    # tone period
    a.lodi(0x04); a.stra(VOLNOISE)     # tone on, loudest

    checks = [
        (KEY_PANEL, 0x40, 1),          # Start -> blue
        (KEY_PANEL, 0x80, 5),          # Game Select -> magenta
        (KEY_COL2, 0x80, 2),           # key 2 / fire -> green
        (KEY_COL2, 0x40, 3),           # key 5 -> cyan
        (KEY_COL3, 0x10, 6),           # Clear -> yellow
    ]
    a.label('loop')
    for i, (addr, mask, colour) in enumerate(checks):
        a.loda(addr)
        a.andi(mask)
        a.bctr(0, f'next{i}')          # not pressed
        a.lodi(colour)
        a.bcta('store')
        a.label(f'next{i}')
    a.lodi(4)                          # nothing pressed -> red
    a.label('store')
    a.stra(PVI_COLOUR)                 # screen colour (background off)
    a.bcta('loop')

    small = '--2k' in sys.argv
    data = bytearray(a.build(4096))
    data[0x0FFF] = 0x56
    if small:
        data = data[:2048]
    args = [x for x in sys.argv[1:] if not x.startswith('--')]
    out = args[0] if args else 'roms/test.bin'
    open(out, 'wb').write(bytes(data))
    print(f'{out}: {len(data)} bytes, program ends at {a.pc:#06x}')


if __name__ == '__main__':
    main()
