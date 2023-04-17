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
UNIT CString;

INTERFACE

{ memory area }

FUNCTION memcpy(VAR dst, src; num : WORD) : POINTER;
FUNCTION memmove(VAR dst, src; num : WORD) : POINTER;
FUNCTION memcmp(VAR p1, p2; num : WORD) : INTEGER;
FUNCTION memchr(VAR p; c: CHAR; num : WORD) : PCHAR;

{ strings area }

FUNCTION strlen(str : PCHAR) : WORD;

FUNCTION strcpy(dst, src : PCHAR) : PCHAR;
FUNCTION strncpy(dst, src : PCHAR; num : WORD ) : PCHAR;

FUNCTION strcat(dst, src : PCHAR) : PCHAR;
FUNCTION strncat(dst, src : PCHAR; num : WORD) : PCHAR;

FUNCTION strcmp(str1, str2 : PCHAR) : INTEGER;
FUNCTION strncmp(str1, str2 : PCHAR; num : WORD) : INTEGER;

FUNCTION strchr(p : PCHAR; c : CHAR) : PCHAR;
FUNCTION strrchr(p : PCHAR; c : CHAR) : PCHAR;

FUNCTION strstr(str1, str2 : PCHAR) : PCHAR;

{ non-standard functions }

PROCEDURE strupr(p : PCHAR);
PROCEDURE strlwr(p : PCHAR);

FUNCTION strhash(p : PCHAR):WORD;

FUNCTION strpas(p : PCHAR) : STRING;
FUNCTION strpcopy(dest : PCHAR; source : STRING) : PCHAR;

IMPLEMENTATION

{ memory area }

FUNCTION memcpy(VAR dst, src; num : WORD) : POINTER;ASSEMBLER;
ASM
        push  ds
        mov   cx, num
        les   di, dst
        lds   si, src
        push  es
        push  di
        cld
        rep   movsb
        pop   ax
        pop   dx
        pop   ds
END;

FUNCTION memmove(VAR dst, src; num : WORD) : POINTER;ASSEMBLER;
ASM
        push  ds
        mov   cx, num
        les   di, dst
        lds   si, src
        push  es
        push  di
        mov   ax, ds
        mov   bx, es
        cmp   ax, bx
        jnz   @nooverlap
        cmp   di, si
        jl    @nooverlap
        std
        add   di, cx
        add   si, cx
        rep   movsb
        jmp   @end
@nooverlap:
        cld
        rep   movsb
@end:   pop   ax
        pop   dx
        pop   ds
END;

FUNCTION memcmp(VAR p1, p2; num : WORD) : INTEGER;ASSEMBLER;
ASM
        push  ds
        mov   cx, num
        les   di, p1
        lds   si, p2
        cld
@cont:
        xor   ax, ax
        or    cx, cx
        jz    @diff
        mov   ah, es:[di]
        inc   di
        lodsb
        dec   cx
        cmp   ah, al
        jnz   @diff
        jmp   @cont
@diff:  sub   ah, al
        mov   al, ah
        cbw
        pop   ds
END;

FUNCTION memchr(VAR p; c: CHAR; num : WORD) : PCHAR;ASSEMBLER;
ASM
        push  es
        cld
        mov   cx, num
        les   di, p
        repne scasb
        or    cx, cx
        jz    @notfound
        mov   dx, es
        mov   ax, di
        dec   ax
        jmp   @end
@notfound:
        xor   ax, ax
        mov   dx, ax
@end:
        pop   es
END;

{ strings area }

FUNCTION strlen(str : PCHAR) : WORD;ASSEMBLER;
ASM
        push  es
        cld
        les   di, str
        xor   ax, ax
        mov   cx, ax
        dec   cx
        repnz scasb
        pop   es
        mov   ax, cx
        neg   ax
        dec   ax
END;

FUNCTION strcpy(dst, src : PCHAR) : PCHAR;ASSEMBLER;
ASM
        push  ds
        push  es
        lds   si, src
        les   di, dst
        push  es
        push  di
        cld
@cont:  lodsb
        stosb
        or    al, al
        jnz   @cont
        pop   ax
        pop   dx
        pop   es
        pop   ds
END;

FUNCTION strncpy(dst, src : PCHAR; num : WORD ) : PCHAR;ASSEMBLER;
ASM
        push  ds
        push  es
        mov   cx, num
        lds   si, src
        les   di, dst
        push  es
        push  di
        cld
@cont:  or    cx, cx
        jz    @pad
        lodsb
        or    al, al
        jz    @pad
        stosb
        dec   cx
        jmp   @cont
@pad:   xor   al, al
        or    cx, cx
        jz    @end
        stosb
        dec   cx
        jmp   @pad
@end:   pop   ax
        pop   dx
        pop   es
        pop   ds
END;

FUNCTION strcat(dst, src : PCHAR) : PCHAR;ASSEMBLER;
ASM
        push  es
        cld
        les   di, dst
        push  es
        push  di
        xor   ax, ax
        mov   cx, ax
        dec   cx
        repnz scasb
        dec   di
        push  ds
        lds   si, src
@cont:  lodsb
        or    al, al
        jz    @end
        stosb
        jmp   @cont
@end:
        pop   ds
        pop   ax
        pop   dx
        pop   es
END;

FUNCTION strncat(dst, src : PCHAR; num : WORD) : PCHAR;ASSEMBLER;
ASM
        push  es
        cld
        les   di, dst
        push  es
        push  di
        xor   ax, ax
        mov   cx, ax
        dec   cx
        repnz scasb
        dec   di
        mov   cx, num
        push  ds
        lds   si, src
@cont:  or    cx, cx
        jz    @end
        lodsb
        or    al, al
        jz    @end
        stosb
        dec   cx
        jmp   @cont
@end:   xor   al, al
        stosb
        pop   ds
        pop   ax
        pop   dx
        pop   es
END;

FUNCTION strcmp(str1, str2 : PCHAR) : INTEGER;ASSEMBLER;
ASM
        push  ds
        les   di, str1
        lds   si, str2
        cld
@cont:
        mov   ah, es:[di]
        inc   di
        lodsb
        cmp   ah, al
        jnz   @diff
        or    al, al
        jz    @diff
        jmp   @cont
@diff:  sub   ah, al
        mov   al, ah
        cbw
        pop   ds
END;

FUNCTION strncmp(str1, str2 : PCHAR; num : WORD) : INTEGER;ASSEMBLER;
ASM
        push  ds
        mov   cx, num
        les   di, str1
        lds   si, str2
        cld
@cont:  xor   ax, ax
        or    cx, cx
        jz    @diff
        mov   ah, es:[di]
        inc   di
        lodsb
        dec   cx
        cmp   ah, al
        jnz   @diff
        or    al, al
        jz    @diff
        jmp   @cont
@diff:  sub   ah, al
        mov   al, ah
        cbw
        pop   ds
END;

FUNCTION strchr(p : PCHAR; c : CHAR) : PCHAR;ASSEMBLER;
ASM
        push  es
        cld
        mov   al, 0
        les   di, p
        push  di
        mov   cx, $FFFF
        push  cx
        repne scasb
        neg   cx
        mov   bx, cx
        mov   al, c
        pop   cx
        pop   di
        repne scasb
        neg   cx
        cmp   cx, bx
        jnc   @notfound
        mov   dx, es
        mov   ax, di
        dec   ax
        jmp   @end
@notfound:
        xor   ax, ax
        mov   dx, ax
@end:
        pop   es
END;

FUNCTION strrchr(p : PCHAR; c : CHAR) : PCHAR;ASSEMBLER;
ASM
        push  es
        cld
        mov   al, 0
        les   di, p
        mov   cx, $FFFF
        cld
        repne scasb
        neg   cx
        inc   cx
        mov   al, c
        std
        repne scasb
        or    cx, cx
        jz    @notfound
        mov   dx, es
        mov   ax, di
        inc   ax
        jmp   @end
@notfound:
        xor   ax, ax
        mov   dx, ax
@end:
        pop   es
END;

FUNCTION strstr(str1, str2 : PCHAR) : PCHAR;
VAR     r   : PCHAR;
        len : WORD;
BEGIN
        r := NIL;
        len := strlen(str2);
        CASE len OF
        0: r := str1;
        1: r := strchr(str1, str2^);
        ELSE BEGIN
                r := strchr(str1, str2^);
                WHILE r <> NIL DO BEGIN
                        IF memcmp(r, str2, len) = 0 THEN BREAK;
                        str1 := r + 1;
                END;
        END;
        END;
        strstr := r;
END;






{ non-standard functions }

PROCEDURE strupr(p : PCHAR);ASSEMBLER;
ASM
        push       ds

        lds        si, p
        push       ds
        pop        es
        cld
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
        or         al, al
        jnz        @cont
@end:
        pop        ds
END;

PROCEDURE strlwr(p : PCHAR);ASSEMBLER;
ASM
        push       ds

        lds        si, p
        push       ds
        pop        es
        cld
        mov        di, si
@cont:
        lodsb
        cmp        al, 'A'
        jl         @noconv
        cmp        al, 'Z'
        jg         @noconv
        add        al, $20
@noconv:
        stosb
        or         al, al
        jnz        @cont
@end:
        pop        ds
END;

FUNCTION strhash(p : PCHAR):WORD;
VAR     h : WORD;
BEGIN
        h := 0;
        WHILE p[0] <> #0 DO BEGIN h := h * 33 + ORD(p[0]); Inc(p); END;
        strhash := h;
END;

FUNCTION strpas(p : PCHAR) : STRING;
VAR     r   : STRING;
        len : WORD;
BEGIN
        len := strlen(p) AND $FF;
        Move(p^, r[1], len);
        r[0] := chr(len);
        strpas := r;
END;

FUNCTION strpcopy(dest : PCHAR; source : STRING) : PCHAR;
VAR     l : BYTE;
BEGIN
        l := ORD(source[0]);
        IF l <> 0 THEN BEGIN
                Move(source[1], dest[0], l);
                Inc(dest, l);
        END;
        dest^ := #0;
        strpcopy := dest;
END;

END.
