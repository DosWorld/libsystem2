{ MIT License

Copyright (c) 2022 Viacheslav Komenda

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
UNIT Str;

INTERFACE

FUNCTION basename(s:STRING):STRING;
FUNCTION getpathname(s:STRING):STRING;
FUNCTION change_ext(s:STRING; new_ext:STRING):STRING;
FUNCTION get_filename_ext(s:STRING):STRING;
FUNCTION poschr(var s : string; c : CHAR) : INTEGER;

PROCEDURE upstr(VAR s : STRING);

FUNCTION hcode(VAR s : STRING):WORD;

FUNCTION is_digit(c : CHAR):BOOLEAN;
FUNCTION is_hdigit(c : CHAR):BOOLEAN;
FUNCTION is_alpha(c : CHAR):BOOLEAN;
FUNCTION is_id(c : CHAR):BOOLEAN;
FUNCTION is_blank(c : CHAR):BOOLEAN;

FUNCTION ltrim(s : STRING):STRING;
FUNCTION rtrim(s : STRING):STRING;
FUNCTION trim(s : STRING):STRING;

FUNCTION starts_with(var s : STRING; start : STRING):BOOLEAN;

FUNCTION rpad(s : STRING; len : INTEGER):STRING;
FUNCTION lpad(s : STRING; len : INTEGER):STRING;

FUNCTION itoa(i : INTEGER):STRING;
FUNCTION wtoa(w : WORD):STRING;
FUNCTION ltoa(l : LONGINT):STRING;
FUNCTION atoi(s : STRING; default_val : INTEGER) : INTEGER;
FUNCTION atow(s : STRING; default_val : WORD) : WORD;
FUNCTION atol(s : STRING; default_val : LONGINT) : LONGINT;
FUNCTION ahtob(str : STRING) : BYTE;

IMPLEMENTATION

FUNCTION get_filename_ext(s : STRING):STRING;
VAR r : STRING;
    i : INTEGER;
BEGIN
        r := '';
        i := Length(s);
        WHILE i <> 0 DO BEGIN
                IF s[i] = '.' THEN BREAK;
                Dec(i);
        END;
        IF i = 0 THEN r := '' ELSE r := copy(s, i + 1, Length(s) - i);
        get_filename_ext := r;
END;

PROCEDURE upstr(var s : STRING);ASSEMBLER;
ASM
        push       ds
        push       es

        lds        si, s
        push       ds
        pop        es
        cld
        lodsb
        mov        cl, al
        or         cl, cl
        jz         @end
        mov        di, si
@cont:
        lodsb
        cmp        al, 'a'
        jl         @noconv
        cmp        al, 'z'
        jg         @noconv
        sub        al, $20
@noconv:
        stosb
        dec        cl
        jnz        @cont
@end:
        pop        es
        pop        ds
END;

FUNCTION basename(s : STRING):STRING;
VAR i : INTEGER;
BEGIN
        FOR i := Length(s) DOWNTO 0 DO BEGIN
                IF s[i] IN [':','\','/'] THEN BREAK;
        END;
        IF i <> 0 THEN s := Copy(s, i+1, Length(s) - i);
        basename := s;
END;

FUNCTION getpathname(s : STRING):STRING;
VAR i : INTEGER;
BEGIN
        FOR i := Length(s) DOWNTO 0 DO BEGIN
                IF s[i] IN [':','\','/'] THEN BREAK;
        END;
        IF i <> 0 THEN s := Copy(s, 1, i);
        getpathname := s;
END;

FUNCTION change_ext(s : STRING; new_ext : STRING):STRING;
VAR     i : INTEGER;
BEGIN
        i := Length(s);
        WHILE i > 0 DO BEGIN
                CASE s[i] OF
                '.': BEGIN s[0] := CHR(i - 1); BREAK; END;
                '/', '\', ':': BREAK;
                END;
                dec(i);
        END;
        change_ext := s + new_ext;
END;

FUNCTION hcode(var s : STRING):WORD;ASSEMBLER;
ASM
        push       ds
        lds        si, s
        cld
        xor        bx, bx
        lodsb
        or         al, al
        jz         @end
        mov        cl, al
@cont:
        mov        ax, 33
        mul        bx
        xchg       bx, ax
        lodsb
        add        bx, ax
        dec        cl
        jnz        @cont
@end:
        mov        ax, bx
        pop        ds
END;

FUNCTION hexb(b : BYTE):STRING;
CONST a : STRING[16] = '0123456789ABCDEF';
BEGIN
        hexb := a[((b SHR 4) AND $0f) + 1] + a[(b AND $0f) + 1];
END;

FUNCTION hexw(w : WORD):STRING;
BEGIN
        hexw := hexb(hi(w)) + hexb(lo(w));
END;

FUNCTION hexdw(dw : LONGINT):STRING;
BEGIN
        hexdw := hexw((dw SHR 16) AND $ffff) + hexw(dw AND $ffff);
END;

FUNCTION hexp(p : PCHAR):STRING;
BEGIN
        hexp := hexw(seg(p[0])) + ':' + hexw(ofs(p[0]));
END;

FUNCTION binb(b : BYTE):STRING;
var s : STRING[8];
    i : INTEGER;
BEGIN
        s[0] := #8;
        FOR i := 7 DOWNTO 0 DO IF (b AND (1 SHL i)) <> 0 THEN s[8-i] := '1' ELSE s[8-i] := '0';
        binb := s;
END;

FUNCTION bindw(l : LONGINT):STRING;
BEGIN
        bindw := Concat(binb(l SHR 24), binb(l SHR 16), binb(l SHR 8), binb(l));
END;

FUNCTION octb(b : BYTE):STRING;
VAR s : STRING[4];
BEGIN
        s := '   ';
        s[3] := CHR($30 + (b AND 7));
        b := b SHR 3;
        s[2] := CHR($30 + (b AND 7));
        b := b SHR 3;
        s[1] := CHR($30 + (b AND 3));
        octb := s;
END;

FUNCTION is_blank(c : CHAR) : BOOLEAN;ASSEMBLER;
ASM
        xor        al, al
        mov        ah, c
        cmp        ah, ' '
        jg         @end
        dec        al
@end:
END;

FUNCTION is_digit(c : CHAR):BOOLEAN;ASSEMBLER;
ASM
        xor        al, al
        mov        ah, c
        cmp        ah, '0'
        jl         @cont1
        cmp        ah, '9'
        jg         @cont1
        dec        al
@cont1:
END;

FUNCTION is_alpha(c : CHAR):BOOLEAN;ASSEMBLER;
ASM
        xor        al, al
        mov        ah, c
        cmp        ah, 'a'
        jl         @cont1
        cmp        ah, 'z'
        jg         @cont1
        dec        al
        jmp        @end
@cont1:
        cmp        ah, 'A'
        jl         @cont2
        cmp        ah, 'Z'
        jg         @cont2
        dec        al
@cont2:
@end:
END;

FUNCTION is_hdigit(c : CHAR):BOOLEAN;ASSEMBLER;
ASM
        xor        al, al
        mov        ah, c
        cmp        ah, 'a'
        jl         @cont1
        cmp        ah, 'f'
        jg         @cont1
        dec        al
        jmp        @end
@cont1:
        cmp        ah, 'A'
        jl         @cont2
        cmp        ah, 'f'
        jg         @cont2
        dec        al
        jmp        @end
@cont2:
        cmp        ah, '0'
        jl         @end
        cmp        ah, '9'
        jg         @end
        dec        al
@end:
END;

FUNCTION is_id(c : CHAR):BOOLEAN;ASSEMBLER;
ASM
        xor        al, al
        mov        ah, c
        cmp        ah, 'a'
        jl         @cont1
        cmp        ah, 'z'
        jg         @cont1
        dec        al
        jmp        @end
@cont1:
        cmp        ah, 'A'
        jl         @cont2
        cmp        ah, 'Z'
        jg         @cont2
        dec        al
        jmp        @end
@cont2:
        cmp        ah, '0'
        jl         @cont3
        cmp        ah, '9'
        jg         @cont3
        dec        al
        jmp        @end
@cont3: cmp        ah, '_'
        jnz        @end
        dec        al
@end:
END;

FUNCTION ltrim(s : STRING):STRING;
VAR k, l : INTEGER;
BEGIN
        k := 1; l := Length(s);
        WHILE k < l DO BEGIN
                IF s[k] > ' ' THEN BREAK;
                Inc(k);
        END;
        IF k <> 1 THEN s := copy(s, k, l - k + 1);
        ltrim := s;
END;

FUNCTION rtrim(s : STRING):STRING;
BEGIN
        WHILE s[0] > #0 DO BEGIN
                IF s[ORD(s[0])] > ' ' THEN BREAK;
                Dec(s[0]);
        END;
        rtrim := s;
END;

FUNCTION trim(s : STRING):STRING;
BEGIN
        trim := ltrim(rtrim(s));
END;

FUNCTION rpad(s : STRING; len : INTEGER):STRING;
BEGIN
        IF Length(s) > len THEN s := copy(s, 1, len)
        ELSE WHILE Length(s) < len DO s := s + ' ';
        rpad := s;
END;

FUNCTION lpad(s : STRING; len : INTEGER):STRING;
BEGIN
        IF Length(s) > len THEN s := Copy(s, 1, len)
        ELSE WHILE Length(s) < len DO s := ' ' + s;
        lpad := s;
END;

FUNCTION itoa(i : INTEGER):STRING;
VAR s : STRING;
BEGIN
        System.Str(i, s);
        itoa := s;
END;

FUNCTION wtoa(w : WORD):STRING;
VAR s : STRING;
BEGIN
        System.Str(w, s);
        wtoa := s;
END;

FUNCTION ltoa(l : LONGINT):STRING;
VAR s : STRING;
BEGIN
        System.Str(l, s);
        ltoa := s;
END;

FUNCTION atol(s : STRING; default_val : LONGINT) : LONGINT;
VAR res : LONGINT; err_pos : INTEGER;
BEGIN
     Val(s, res, err_pos);
     IF err_pos <> 0 THEN res := default_val;
     atol := res;
END;

FUNCTION atoi(s : STRING; default_val : INTEGER) : INTEGER;
VAR res : INTEGER; err_pos : INTEGER;
BEGIN
     Val(s, res, err_pos);
     IF err_pos <> 0 THEN res := default_val;
     atoi := res;
END;

FUNCTION atow(s : STRING; default_val : WORD) : WORD;
VAR res : INTEGER; err_pos : INTEGER;
BEGIN
     Val(s, res, err_pos);
     IF err_pos <> 0 THEN res := default_val;
     atow := res;
END;

FUNCTION ahtob(str : STRING) : BYTE;
VAR r  : BYTE;
    i  : INTEGER;
    c  : CHAR;
    k  : BYTE;
BEGIN
        r := 0;
        IF Length(str) = 1 THEN str := '0' + str;
        upstr(str);
        IF Length(str) > 2 THEN str := Copy(str, 1, 2);
        FOR i := 1 TO 2 DO BEGIN
                c := str[i];
                k := 0;
                IF c IN ['0'..'9'] THEN k := ORD(c) - ORD('0')
                ELSE IF c IN ['A'..'F'] THEN k := ORD(c) - ORD('A') + 10;
                r := (r SHL 4) or (k AND $0F);
        END;
        ahtob := r;
END;

FUNCTION starts_with(var s : STRING; start : STRING):BOOLEAN;
VAR n : STRING;
BEGIN
        n := s;
        IF s[0] >= start[0] THEN BEGIN
                n := s; n[0] := start[0];
                starts_with := n = start;
        END ELSE starts_with := FALSE;
END;

FUNCTION unquote(str : STRING) : STRING;
BEGIN
        IF Length(str) > 0 THEN BEGIN
                IF (str[1] = '"') AND (str[Length(str)] = '"') THEN BEGIN
                        str := copy(str, 2, Length(str) - 2);
                END;
        END;
        unquote := str;
END;

FUNCTION poschr(var s : string; c : CHAR) : INTEGER;ASSEMBLER;
ASM
        push       ds
        mov        ah, c
        lds        si, s
        mov        bx, -1
        cld
        lodsb
        mov        cl, al
@cont:
        or         cl, cl
        jz         @end;
        lodsb
        dec        cl
        cmp        al, ah
        jne        @cont
        mov        bl, cl
        xor        bh, bh
@end:
        mov        ax, bx
        pop        ds
END;

END.
