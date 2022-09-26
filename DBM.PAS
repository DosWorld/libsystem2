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
UNIT DBM;
{ =========================================================================
  This is unit implements dbu files (like a .dbt) - container for memo fields
  with variable length. Free blocks will be reused.
  ========================================================================= }
INTERFACE

USES System2;

TYPE
DBM_HDR = RECORD
        sign       : WORD;
        next       : LONGINT;
        records    : LONGINT;
        root       : LONGINT;
        size       : WORD;
END;
DBM_REC = RECORD
        next       : LONGINT;
        size       : WORD;
END;

DBMFile = RECORD
        f          : BFILE;
        header     : DBM_HDR;
        crec       : DBM_REC;
        crecno     : LONGINT;
        needupdate : BOOLEAN;
        rblk_size  : WORD;
        data       : PCHAR;
END;

PROCEDURE dbm_reset(VAR f : DBMFile; fname : STRING; blk_size : WORD);
PROCEDURE dbm_rewrite(VAR f : DBMFile; fname : STRING; blk_size : WORD);
PROCEDURE dbm_rewrite_temp(VAR f : DBMFile; blk_size : WORD);

FUNCTION dbm_isopen(VAR f : DBMFile) : BOOLEAN;

FUNCTION dbm_getroot(VAR f : DBMFile):LONGINT;
PROCEDURE dbm_setroot(VAR f : DBMFile; new_root : LONGINT);

PROCEDURE dbm_get(VAR f : DBMFile; rec : LONGINT; VAR b; size : WORD);
FUNCTION dbm_add(VAR f : DBMFile; VAR b; size : WORD) : LONGINT;
PROCEDURE dbm_put(VAR f : DBMFile; rec : LONGINT; VAR b; size : WORD);
FUNCTION dbm_size(VAR f : DBMFile; rec : LONGINT) : LONGINT;

PROCEDURE dbm_free(VAR f : DBMFile; rec : LONGINT);

PROCEDURE dbm_close(VAR f : DBMFile);

IMPLEMENTATION

CONST
DBM_SIGN = $7744;

FUNCTION norm_blk_size(blk_size : WORD) : WORD;
BEGIN
        blk_size := blk_size + SizeOf(DBM_REC);
        IF blk_size < SizeOf(DBM_HDR) THEN blk_size := SizeOf(DBM_HDR);
        IF (blk_size AND 3) <> 0 THEN blk_size := ((blk_size SHR 2) + 1) SHL 2;
        norm_blk_size := blk_size;
END;

PROCEDURE dbm_update(VAR f : DBMFile);
BEGIN
        IF (f.needupdate) AND (f.crecno <> 0) THEN BEGIN
                Seek(f.f, f.crecno * f.header.size);
                BlockWrite(f.f, f.crec, SizeOf(DBM_REC));
                BlockWrite(f.f, f.data[0], f.rblk_size);
        END;
        f.needupdate := FALSE;
END;

PROCEDURE dbm_go(VAR f : DBMFile; recno : LONGINT);
BEGIN
        IF recno = f.crecno THEN EXIT;
        dbm_update(f);
        FillChar(f.data[0], f.rblk_size, #0);
        f.crec.next := 0;
        f.crec.size := 0;
        f.crecno := recno;
        Seek(f.f, recno * f.header.size);
        BlockRead(f.f, f.crec, SizeOf(DBM_REC));
        BlockRead(f.f, f.data[0], f.rblk_size);
END;

PROCEDURE dbm_reset(VAR f : DBMFile; fname : STRING; blk_size : WORD);
VAR     rblk_size : WORD;
BEGIN
        FillChar(f, SizeOf(DBMFile), #0);
        Assign(f.f, fname);
        Reset(f.f);
        rblk_size := norm_blk_size(blk_size);
        IF NOT IsOpen(f.f) THEN dbm_rewrite(f, fname, blk_size)
        ELSE IF SizeOf(DBM_HDR) <> BlockRead(f.f, f.header, SizeOf(DBM_HDR)) THEN BEGIN
                Close(f.f);
                dbm_rewrite(f, fname, blk_size);
        END ELSE IF (f.header.sign = DBM_SIGN) AND (f.header.size = rblk_size) THEN BEGIN
                f.rblk_size := f.header.size - SizeOf(DBM_REC);
                GetMem(f.data, f.rblk_size);
                FillChar(f.data[0], f.rblk_size, #0);
        END ELSE BEGIN
                Close(f.f);
                dbm_rewrite(f, fname, blk_size);
        END;
END;

PROCEDURE _dbm_rewrite(VAR f : DBMFile);
BEGIN
        IF IsOpen(f.f) THEN BEGIN
                f.header.sign := DBM_SIGN;
                f.header.next := 0;
                f.header.records := 0;
                f.header.root := 0;
                f.crecno := 0;
                f.needupdate := FALSE;
                FillChar(f.crec, SizeOf(DBM_REC), #0);
                GetMem(f.data, f.rblk_size);
                FillChar(f.data[0], f.rblk_size, #0);
                Seek(f.f, 0);
                BlockWrite(f.f, f.header, SizeOf(DBM_HDR));
                BlockWrite(f.f, f.data[0], f.header.size - SizeOf(DBM_HDR));
        END;
END;

PROCEDURE dbm_rewrite(VAR f : DBMFile; fname : STRING; blk_size : WORD);
BEGIN
        FillChar(f, SizeOf(DBMFile), #0);
        Assign(f.f, fname);
        ReWrite(f.f);
        f.header.size := norm_blk_size(blk_size);
        f.rblk_size := f.header.size - SizeOf(DBM_REC);
        _dbm_rewrite(f);
END;

PROCEDURE dbm_rewrite_temp(VAR f : DBMFile; blk_size : WORD);
BEGIN
        FillChar(f, SizeOf(DBMFile), #0);
        ReWriteTemp(f.f);
        f.header.size := norm_blk_size(blk_size);
        f.rblk_size := f.header.size - SizeOf(DBM_REC);
        _dbm_rewrite(f);
END;

FUNCTION dbm_isopen(VAR f : DBMFile) : BOOLEAN;
BEGIN
        dbm_isopen := IsOpen(f.f);
END;

PROCEDURE dbm_close(VAR f : DBMFile);
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        dbm_update(f);
        Seek(f.f, 0);
        BlockWrite(f.f, f.header, SizeOf(DBM_HDR));
        Close(f.f);
        IF f.data <> NIL THEN FreeMem(f.data, f.rblk_size);
        FillChar(f, SizeOf(DBMFile), #0);
END;

PROCEDURE dbm_free(VAR f : DBMFile; rec : LONGINT);
VAR     n : LONGINT;
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        WHILE rec <> 0 DO BEGIN
                dbm_go(f, rec);
                n := f.crec.next;
                f.crec.next := f.header.next;
                f.crec.size := 0;
                f.needupdate := TRUE;
                f.header.next := rec;
                FillChar(f.data[0], f.rblk_size, #0);
                rec := n;
        END;
END;

FUNCTION dbm_alloc(VAR f : DBMFile) : LONGINT;
VAR     r : LONGINT;
BEGIN
        IF f.header.next <> 0 THEN BEGIN
                r := f.header.next;
                dbm_go(f, r);
                f.header.next := f.crec.next;
        END ELSE BEGIN
                Inc(f.header.records);
                r := f.header.records;
        END;
        dbm_go(f, r);
        f.crec.next := 0;
        f.crec.size := 0;
        f.needupdate := TRUE;
        dbm_alloc := r;
END;

FUNCTION dbm_size(VAR f : DBMFile; rec : LONGINT) : LONGINT;
VAR     r : LONGINT;
BEGIN
        r := 0;
        IF IsOpen(f.f) THEN BEGIN 
                WHILE rec <> 0 DO BEGIN
                        dbm_go(f, rec);
                        Inc(r, f.crec.size);
                        rec := f.crec.next;
                END;
        END;
        dbm_size := r;
END;

PROCEDURE dbm_get(VAR f : DBMFile; rec : LONGINT; VAR b; size : WORD);
VAR     p : PCHAR;
        g : WORD;
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        p := @b;
        WHILE (size <> 0) AND (rec <> 0) DO BEGIN
                dbm_go(f, rec);
                g := f.crec.size;
                IF g > size THEN g := size;
                Move(f.data[0], p[0], g);
                Dec(size, g);
                Inc(p, g);
                rec := f.crec.next;
        END;
END;

FUNCTION dbm_add(VAR f : DBMFile; VAR b; size : WORD) : LONGINT;
VAR     root, prec, crec : LONGINT;
        p        : PCHAR;
        csize    : WORD;
BEGIN
        root := 0;
        IF IsOpen(f.f) THEN BEGIN
                p := @b;
                prec := 0;
                WHILE size <> 0 DO BEGIN
                        crec := dbm_alloc(f);
                        IF root = 0 THEN root := crec;
                        IF prec <> 0 THEN BEGIN
                                dbm_go(f, prec);
                                f.crec.next := crec;
                                f.needupdate := TRUE;
                        END;
                        prec := crec;
                        dbm_go(f, crec);
                        csize := size;
                        IF csize > f.rblk_size THEN csize := f.rblk_size;
                        Move(p[0], f.data[0], csize);
                        f.crec.size := csize;
                        f.needupdate := TRUE;
                        Dec(size, csize);
                        Inc(p, csize);
                END;
        END;
        dbm_add := root;
END;

PROCEDURE dbm_put(VAR f : DBMFile; rec : LONGINT; VAR b; size : WORD);
VAR     crec : LONGINT;
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        dbm_go(f, rec);
        crec := f.crec.next;
        f.crec.next := 0;
        f.crec.size := 0;
        f.needupdate := TRUE;
        dbm_free(f, crec);
        dbm_go(f, rec);
        dbm_free(f, rec);
        dbm_add(f, b, size);
END;

FUNCTION dbm_getroot(VAR f : DBMFile):LONGINT;
BEGIN
        dbm_getroot := f.header.root;
END;

PROCEDURE dbm_setroot(VAR f : DBMFile; new_root : LONGINT);
BEGIN
        f.header.root := new_root;
END;

END.
