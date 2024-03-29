{ MIT License

Copyright (c) 2020 Viacheslav Komenda

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. }
{$A+,I-,S-,R-,D+,L+,Q-,F-,G-,O-,B-}
UNIT KMInput;

INTERFACE

{ --- Keyboard ------------------------------------------------------ }

CONST

SCAN_ESC           = $01;

SCAN_UP            = $48;
SCAN_DOWN          = $50;
SCAN_LEFT          = $4B;
SCAN_RIGHT         = $4D;

SCAN_CTRL_LEFT     = $73;
SCAN_CTRL_RIGHT    = $74;
SCAN_CTRL_UP       = $8D;
SCAN_CTRL_DOWN     = $91;

SCAN_INS           = $52;
SCAN_HOME          = $47;
SCAN_PGUP          = $49;
SCAN_DEL           = $53;
SCAN_END           = $4F;
SCAN_PGDN          = $51;

SCAN_CTRL_HOME     = $77;
SCAN_CTRL_PGUP     = $84;
SCAN_CTRL_END      = $75;
SCAN_CTRL_PGDN     = $76;

SCAN_F1            = $3B;
SCAN_F2            = $3C;
SCAN_F3            = $3D;
SCAN_F4            = $3E;
SCAN_F5            = $3F;
SCAN_F6            = $40;
SCAN_F7            = $41;
SCAN_F8            = $42;
SCAN_F9            = $43;
SCAN_F10           = $44;
SCAN_F11           = $85;
SCAN_F12           = $86;

SCAN_ALT_F1        = $68;
SCAN_ALT_F2        = $69;
SCAN_ALT_F3        = $6A;
SCAN_ALT_F4        = $6B;
SCAN_ALT_F5        = $6C;
SCAN_ALT_F6        = $6D;
SCAN_ALT_F7        = $6E;
SCAN_ALT_F8        = $6F;
SCAN_ALT_F9        = $70;
SCAN_ALT_F10       = $71;
SCAN_ALT_F11       = $8B;
SCAN_ALT_F12       = $8C;

SCAN_SHIFT_F1      = $54;
SCAN_SHIFT_F2      = $55;
SCAN_SHIFT_F3      = $56;
SCAN_SHIFT_F4      = $57;
SCAN_SHIFT_F5      = $58;
SCAN_SHIFT_F6      = $59;
SCAN_SHIFT_F7      = $5A;
SCAN_SHIFT_F8      = $5B;
SCAN_SHIFT_F9      = $5C;
SCAN_SHIFT_F10     = $5D;
SCAN_SHIFT_F11     = $87;
SCAN_SHIFT_F12     = $88;

SCAN_CTRL_F1       = $5E;
SCAN_CTRL_F2       = $5F;
SCAN_CTRL_F3       = $60;
SCAN_CTRL_F4       = $61;
SCAN_CTRL_F5       = $62;
SCAN_CTRL_F6       = $63;
SCAN_CTRL_F7       = $64;
SCAN_CTRL_F8       = $65;
SCAN_CTRL_F9       = $66;
SCAN_CTRL_F10      = $67;
SCAN_CTRL_F11      = $89;
SCAN_CTRL_F12      = $8A;

{ first row }
SCAN_TILDA         = $29;
SCAN_1             = $02;
SCAN_2             = $03;
SCAN_3             = $04;
SCAN_4             = $05;
SCAN_5             = $06;
SCAN_6             = $07;
SCAN_7             = $08;
SCAN_8             = $09;
SCAN_9             = $0A;
SCAN_0             = $0B;
SCAN_MINUS         = $0C;
SCAN_EQ            = $0D;
SCAN_BS            = $0E;

{ second row }
SCAN_TAB           = $0F;
SCAN_Q             = $10;
SCAN_W             = $11;
SCAN_E             = $12;
SCAN_R             = $13;
SCAN_T             = $14;
SCAN_Y             = $15;
SCAN_U             = $16;
SCAN_I             = $17;
SCAN_O             = $18;
SCAN_P             = $19;
SCAN_LBRAKET       = $1A;
SCAN_RBRAKET       = $1B;
SCAN_BACK_SLASH    = $2B;

{ third row }
SCAN_A             = $1E;
SCAN_S             = $1F;
SCAN_D             = $20;
SCAN_F             = $21;
SCAN_G             = $22;
SCAN_H             = $23;
SCAN_J             = $24;
SCAN_K             = $25;
SCAN_L             = $26;
SCAN_DOTCOMA       = $27;
SCAN_QUOTE         = $28;
SCAN_ENTER         = $1c;

{ fourth row }
SCAN_Z             = $2C;
SCAN_X             = $2D;
SCAN_C             = $2E;
SCAN_V             = $2F;
SCAN_B             = $30;
SCAN_N             = $31;
SCAN_M             = $32;
SCAN_COMA          = $33;
SCAN_DOT           = $34;
SCAN_SLASH         = $35;

SCAN_SPACE         = $39;

SCAN_GREY_MINUS    = $4A;
SCAN_GREY_PLUS     = $4E;

FUNCTION kbd_getkey : WORD;
FUNCTION kbd_haskey : BOOLEAN;
FUNCTION kbd_getflags : BYTE;
PROCEDURE kbd_reset;
PROCEDURE kbd_fast;

FUNCTION is_ctrl(flags : BYTE) : BOOLEAN;
FUNCTION is_alt(flags : BYTE) : BOOLEAN;
FUNCTION is_shift(flags : BYTE) : BOOLEAN;

{ --- Mouse ------------------------------------------------------ }

CONST

MOUSE_B1 = 1;
MOUSE_B2 = 2;

PROCEDURE mouse_show;
PROCEDURE mouse_hide;
FUNCTION mouse_visible : BOOLEAN;
FUNCTION mouse_buttons : BYTE;
FUNCTION mouse_getx : INTEGER;
FUNCTION mouse_gety : INTEGER;
FUNCTION mouse_avail : BOOLEAN;

IMPLEMENTATION

VAR     have_ext_kb : BOOLEAN;
        have_122_kb : BOOLEAN;
        mouse_present, mouse_state : BOOLEAN;

{ --- Keyboard ------------------------------------------------------ }

FUNCTION kbd_getkey : WORD;ASSEMBLER;
ASM
        cmp        BYTE ptr have_122_kb, 0
        jne        @h122
        cmp        BYTE ptr have_ext_kb, 0
        jne        @hext
        xor        ax, ax
        jmp        @end
@h122:
        mov        ah, $20
        jmp        @end
@hext:
        mov        ah, $10
@end:
        int        $16
END;

FUNCTION kbd_haskey : BOOLEAN;ASSEMBLER;
ASM
        cmp        BYTE ptr have_122_kb, 0
        jne        @h122
        cmp        BYTE ptr have_ext_kb, 0
        jne        @hext

        mov        ah, 1
        jmp        @end
@hext:
        mov        ah, $11
        jmp        @end
@h122:
        mov        ah, $21
@end:
        int        $16
        mov        cx, 0
        jz         @nokey
        dec        cx
@nokey:
        mov        ax, cx
END;

FUNCTION kbd_getflags : BYTE;ASSEMBLER;
ASM
        cmp        BYTE ptr have_122_kb, 0
        jne        @h122
        cmp        BYTE ptr have_ext_kb, 0
        jne        @hext

        mov       ah, 2
        jmp       @end
@hext:
        mov       ah, $12
        jmp       @end
@h122:
        mov       ah, $22

@end:
        int       $16
END;

FUNCTION is_ctrl(flags : BYTE) : BOOLEAN;ASSEMBLER;
ASM
        mov        al, flags
        and        al, $4
END;

FUNCTION is_alt(flags : BYTE) : BOOLEAN;ASSEMBLER;
ASM
        mov        al, flags
        and        al, $8
END;

FUNCTION is_shift(flags : BYTE) : BOOLEAN;ASSEMBLER;
ASM
        mov        al, flags
        and        al, $3
END;

PROCEDURE kbd_fast;ASSEMBLER;
ASM
        mov        ax, $0305
        xor        bx, bx
        int        $16
END;

PROCEDURE kbd_reset;
BEGIN
        WHILE kbd_haskey DO kbd_getkey;
END;

{ --- Mouse ------------------------------------------------------ }

FUNCTION mouse_avail : BOOLEAN;ASSEMBLER;
ASM
        mov      al, mouse_present
END;

FUNCTION mouse_visible : BOOLEAN;ASSEMBLER;
ASM
        mov       al, mouse_present
        or        al, al
        jz        @nomouse
        mov       al, mouse_state
@nomouse:
END;

PROCEDURE mouse_show;ASSEMBLER;
ASM
        mov       al, mouse_present
        or        al, al
        jz        @nomouse
        mov       ax, 1
        int       $33
        mov       al, 1
        mov       mouse_state, al
@nomouse:
END;

PROCEDURE mouse_hide;ASSEMBLER;
ASM
        mov       al, mouse_present
        or        al, al
        jz        @nomouse
        mov       ax, 2
        xor       al, al
        mov       mouse_state, al
@nomouse:
END;

FUNCTION mouse_buttons : BYTE;ASSEMBLER;
ASM
        mov       al, mouse_present
        or        al, al
        jz        @nomouse
        mov       ax, 3
        int       $33
        mov       al, bl
        and       al, 3
@nomouse:
END;

FUNCTION mouse_getx : INTEGER;ASSEMBLER;
ASM
        mov       al, mouse_present
        or        al, al
        jz        @nomouse
        mov       ax, 3
        int       $33
        mov       ax, cx
        mov       cl ,3
        shr       ax, cl
@nomouse:
END;

FUNCTION mouse_gety : INTEGER;ASSEMBLER;
ASM
        mov       al, mouse_present
        or        al, al
        jz        @nomouse
        mov       ax, 3
        int       $33
        mov       ax, dx
        mov       cl ,3
        shr       ax, cl
@nomouse:
END;

BEGIN
ASM
{ check keyboard }
        mov        ax, $0900
        int        $16
        push       ax
        and        al, $20
        mov        have_ext_kb, al
        pop        ax
        and        al, $40
        mov        have_122_kb, al
{ check mouse }
        xor       ax, ax
        int       $33
        mov       mouse_present, al
END;
END.
