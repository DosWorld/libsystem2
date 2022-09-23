{  MIT License

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
SOFTWARE.
}
{$A-,I-,S-,R-,D-,L-,Q-,F-,G-,O-,B-}
UNIT DBU;
{ =========================================================================
  This is unit implements dbu files (like a .dbt) - container for memo fields.
  ========================================================================= }
INTERFACE

USES System2;

TYPE
DBU_HDR = RECORD
        sign       : STRING[3];
        next       : LONGINT;
        records    : LONGINT;
        size       : WORD;
END;
DBU_REC = RECORD
        next       : LONGINT;
        size       : WORD;
END;

DBUFile = RECORD
        f          : BFILE;
        header     : DBU_HDR;
        crec       : DBU_REC;
        crecno     : LONGINT;
        needupdate : BOOLEAN;
        rblk_size  : WORD;
        data       : PCHAR;
END;

PROCEDURE dbu_reset(VAR f : DBUFile; fname : STRING; blk_size : WORD);
PROCEDURE dbu_rewrite(VAR f : DBUFile; fname : STRING; blk_size : WORD);
PROCEDURE dbu_rewrite_temp(VAR f : DBUFile; blk_size : WORD);

FUNCTION dbu_isopen(VAR f : DBUFile) : BOOLEAN;

PROCEDURE dbu_get(VAR f : DBUFile; rec : LONGINT; VAR b; size : WORD);
FUNCTION dbu_add(VAR f : DBUFile; VAR b; size : WORD) : LONGINT;
PROCEDURE dbu_put(VAR f : DBUFile; rec : LONGINT; VAR b; size : WORD);
FUNCTION dbu_size(VAR f : DBUFile; rec : LONGINT) : LONGINT;

PROCEDURE dbu_free(VAR f : DBUFile; rec : LONGINT);

PROCEDURE dbu_close(VAR f : DBUFile);

IMPLEMENTATION

CONST
DBU_SIGN : STRING[3] = 'DBU';

FUNCTION norm_blk_size(blk_size : WORD) : WORD;
BEGIN
        blk_size := blk_size + SizeOf(DBU_REC);
        IF blk_size < SizeOf(DBU_HDR) THEN blk_size := SizeOf(DBU_HDR);
        IF (blk_size AND 3) <> 0 THEN blk_size := ((blk_size SHR 2) + 1) SHL 2;
        norm_blk_size := blk_size;
END;

PROCEDURE dbu_update(VAR f : DBUFile);
BEGIN
        IF (f.needupdate) AND (f.crecno <> 0) THEN BEGIN
                Seek(f.f, f.crecno * f.header.size);
                BlockWrite(f.f, f.crec, SizeOf(DBU_REC));
                BlockWrite(f.f, f.data[0], f.rblk_size);
        END;
        f.needupdate := FALSE;
END;

PROCEDURE dbu_go(VAR f : DBUFile; recno : LONGINT);
BEGIN
        IF recno = f.crecno THEN EXIT;
        dbu_update(f);
        FillChar(f.data[0], f.rblk_size, #0);
        f.crec.next := 0;
        f.crec.size := 0;
        f.crecno := recno;
        Seek(f.f, recno * f.header.size);
        BlockRead(f.f, f.crec, SizeOf(DBU_REC));
        BlockRead(f.f, f.data[0], f.rblk_size);
END;

PROCEDURE dbu_reset(VAR f : DBUFile; fname : STRING; blk_size : WORD);
VAR     rblk_size : WORD;
BEGIN
        FillChar(f, SizeOf(DBUFile), #0);
        Assign(f.f, fname);
        Reset(f.f);
        rblk_size := norm_blk_size(blk_size);
        IF NOT IsOpen(f.f) THEN dbu_rewrite(f, fname, blk_size)
        ELSE IF SizeOf(DBU_HDR) <> BlockRead(f.f, f.header, SizeOf(DBU_HDR)) THEN BEGIN
                Close(f.f);
                dbu_rewrite(f, fname, blk_size);
        END ELSE IF (f.header.sign = DBU_SIGN) AND (f.header.size = rblk_size) THEN BEGIN
                f.rblk_size := f.header.size - SizeOf(DBU_REC);
                GetMem(f.data, f.rblk_size);
                FillChar(f.data[0], f.rblk_size, #0);
        END ELSE BEGIN
                Close(f.f);
                dbu_rewrite(f, fname, blk_size);
        END;
END;

PROCEDURE _dbu_rewrite(VAR f : DBUFile);
BEGIN
        IF IsOpen(f.f) THEN BEGIN
                f.header.sign := DBU_SIGN;
                f.header.next := 0;
                f.header.records := 0;
                f.crecno := 0;
                f.needupdate := FALSE;
                FillChar(f.crec, SizeOf(DBU_REC), #0);
                GetMem(f.data, f.rblk_size);
                FillChar(f.data[0], f.rblk_size, #0);
                Seek(f.f, 0);
                BlockWrite(f.f, f.header, SizeOf(DBU_HDR));
                BlockWrite(f.f, f.data[0], f.header.size - SizeOf(DBU_HDR));
        END;
END;

PROCEDURE dbu_rewrite(VAR f : DBUFile; fname : STRING; blk_size : WORD);
BEGIN
        FillChar(f, SizeOf(DBUFile), #0);
        Assign(f.f, fname);
        ReWrite(f.f);
        f.header.size := norm_blk_size(blk_size);
        f.rblk_size := f.header.size - SizeOf(DBU_REC);
        _dbu_rewrite(f);
END;

PROCEDURE dbu_rewrite_temp(VAR f : DBUFile; blk_size : WORD);
BEGIN
        FillChar(f, SizeOf(DBUFile), #0);
        ReWriteTemp(f.f);
        f.header.size := norm_blk_size(blk_size);
        f.rblk_size := f.header.size - SizeOf(DBU_REC);
        _dbu_rewrite(f);
END;

FUNCTION dbu_isopen(VAR f : DBUFile) : BOOLEAN;
BEGIN
        dbu_isopen := IsOpen(f.f);
END;

PROCEDURE dbu_close(VAR f : DBUFile);
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        dbu_update(f);
        Seek(f.f, 0);
        BlockWrite(f.f, f.header, SizeOf(DBU_HDR));
        Close(f.f);
        IF f.data <> NIL THEN FreeMem(f.data, f.rblk_size);
        FillChar(f, SizeOf(DBUFile), #0);
END;

PROCEDURE dbu_free(VAR f : DBUFile; rec : LONGINT);
VAR     n : LONGINT;
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        WHILE rec <> 0 DO BEGIN
                dbu_go(f, rec);
                n := f.crec.next;
                f.crec.next := f.header.next;
                f.crec.size := 0;
                f.needupdate := TRUE;
                f.header.next := rec;
                FillChar(f.data[0], f.rblk_size, #0);
                rec := n;
        END;
END;

FUNCTION dbu_alloc(VAR f : DBUFile) : LONGINT;
VAR     r : LONGINT;
BEGIN
        IF f.header.next <> 0 THEN BEGIN
                r := f.header.next;
                dbu_go(f, r);
                f.header.next := f.crec.next;
        END ELSE BEGIN
                Inc(f.header.records);
                r := f.header.records;
        END;
        dbu_go(f, r);
        f.crec.next := 0;
        f.crec.size := 0;
        f.needupdate := TRUE;
        dbu_alloc := r;
END;

FUNCTION dbu_size(VAR f : DBUFile; rec : LONGINT) : LONGINT;
VAR     r : LONGINT;
BEGIN
        r := 0;
        IF IsOpen(f.f) THEN BEGIN 
                WHILE rec <> 0 DO BEGIN
                        dbu_go(f, rec);
                        Inc(r, f.crec.size);
                        rec := f.crec.next;
                END;
        END;
        dbu_size := r;
END;

PROCEDURE dbu_get(VAR f : DBUFile; rec : LONGINT; VAR b; size : WORD);
VAR     p : PCHAR;
        g : WORD;
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        p := @b;
        WHILE (size <> 0) AND (rec <> 0) DO BEGIN
                dbu_go(f, rec);
                g := f.crec.size;
                IF g > size THEN g := size;
                Move(f.data[0], p[0], g);
                Dec(size, g);
                Inc(p, g);
                rec := f.crec.next;
        END;
END;

FUNCTION dbu_add(VAR f : DBUFile; VAR b; size : WORD) : LONGINT;
VAR     root, prec, crec : LONGINT;
        p        : PCHAR;
        csize    : WORD;
BEGIN
        root := 0;
        IF IsOpen(f.f) THEN BEGIN
                p := @b;
                prec := 0;
                WHILE size <> 0 DO BEGIN
                        crec := dbu_alloc(f);
                        IF root = 0 THEN root := crec;
                        IF prec <> 0 THEN BEGIN
                                dbu_go(f, prec);
                                f.crec.next := crec;
                                f.needupdate := TRUE;
                        END;
                        prec := crec;
                        dbu_go(f, crec);
                        csize := size;
                        IF csize > f.rblk_size THEN csize := f.rblk_size;
                        Move(p[0], f.data[0], csize);
                        f.crec.size := csize;
                        f.needupdate := TRUE;
                        Dec(size, csize);
                        Inc(p, csize);
                END;
        END;
        dbu_add := root;
END;

PROCEDURE dbu_put(VAR f : DBUFile; rec : LONGINT; VAR b; size : WORD);
VAR     crec : LONGINT;
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        dbu_go(f, rec);
        crec := f.crec.next;
        f.crec.next := 0;
        f.crec.size := 0;
        f.needupdate := TRUE;
        dbu_free(f, crec);
        dbu_go(f, rec);
        dbu_free(f, rec);
        dbu_add(f, b, size);
END;

END.
