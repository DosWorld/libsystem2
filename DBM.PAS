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
SOFTWARE. }
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

DBMFile = RECORD
        f          : BFILE;
        header     : DBM_HDR;
        rblk_size  : WORD;
END;

PROCEDURE dbm_Reset(VAR f : DBMFile; fname : STRING; blk_size : WORD);
PROCEDURE dbm_ReWrite(VAR f : DBMFile; fname : STRING; blk_size : WORD);
PROCEDURE dbm_ReWriteTemp(VAR f : DBMFile; blk_size : WORD);

FUNCTION dbm_IsOpen(VAR f : DBMFile) : BOOLEAN;

FUNCTION dbm_GetRoot(VAR f : DBMFile):LONGINT;
PROCEDURE dbm_SetRoot(VAR f : DBMFile; new_root : LONGINT);

FUNCTION dbm_Add(VAR f : DBMFile; VAR b; size : WORD) : LONGINT;
PROCEDURE dbm_Get(VAR f : DBMFile; rec : LONGINT; VAR b; size : WORD);
PROCEDURE dbm_Put(VAR f : DBMFile; rec : LONGINT; VAR b; size : WORD);
FUNCTION dbm_Size(VAR f : DBMFile; rec : LONGINT) : LONGINT;

PROCEDURE dbm_Free(VAR f : DBMFile; rec : LONGINT);

PROCEDURE dbm_Close(VAR f : DBMFile);

IMPLEMENTATION

CONST
DBM_SIGN = $4D44;
ADDED_DATA = SizeOf(LONGINT) + SizeOf(WORD);

FUNCTION _norm_blk_size(blk_size : WORD) : WORD;
BEGIN
        blk_size := blk_size + ADDED_DATA;
        IF blk_size < SizeOf(DBM_HDR) THEN blk_size := SizeOf(DBM_HDR);
        IF (blk_size AND 3) <> 0 THEN blk_size := ((blk_size SHR 2) + 1) SHL 2;
        _norm_blk_size := blk_size;
END;

FUNCTION _go(VAR f : DBMFile; recno : LONGINT) : LONGINT;
VAR     r : LONGINT;
BEGIN
        r := recno * f.header.size;
        Seek(f.f, r);
        _go := r;
END;

PROCEDURE dbm_Reset(VAR f : DBMFile; fname : STRING; blk_size : WORD);
VAR     rblk_size : WORD;
BEGIN
        FillChar(f, SizeOf(DBMFile), #0);
        Assign(f.f, fname);
        Reset(f.f);
        rblk_size := _norm_blk_size(blk_size);
        IF NOT IsOpen(f.f) THEN dbm_rewrite(f, fname, blk_size)
        ELSE IF SizeOf(DBM_HDR) <> BlockRead(f.f, f.header, SizeOf(DBM_HDR)) THEN BEGIN
                Close(f.f);
                dbm_ReWrite(f, fname, blk_size);
        END ELSE IF (f.header.sign = DBM_SIGN) AND (f.header.size = rblk_size) THEN BEGIN
                f.rblk_size := f.header.size - ADDED_DATA;
        END ELSE BEGIN
                Close(f.f);
                dbm_ReWrite(f, fname, blk_size);
        END;
END;

PROCEDURE _rewrite(VAR f : DBMFile);
VAR     i : INTEGER;
BEGIN
        IF IsOpen(f.f) THEN BEGIN
                f.header.sign := DBM_SIGN;
                f.header.next := 0;
                f.header.records := 0;
                f.header.root := 0;
                Seek(f.f, 0);
                BlockWrite(f.f, f.header, SizeOf(DBM_HDR));
                FOR i := 1 TO f.header.size - SizeOf(DBM_HDR) DO WriteByte(f.f, 0);
        END;
END;

PROCEDURE dbm_ReWrite(VAR f : DBMFile; fname : STRING; blk_size : WORD);
BEGIN
        FillChar(f, SizeOf(DBMFile), #0);
        Assign(f.f, fname);
        ReWrite(f.f);
        f.header.size := _norm_blk_size(blk_size);
        f.rblk_size := f.header.size - ADDED_DATA;
        _rewrite(f);
END;

PROCEDURE dbm_ReWriteTemp(VAR f : DBMFile; blk_size : WORD);
BEGIN
        FillChar(f, SizeOf(DBMFile), #0);
        ReWriteTemp(f.f);
        f.header.size := _norm_blk_size(blk_size);
        f.rblk_size := f.header.size - ADDED_DATA;
        _rewrite(f);
END;

FUNCTION dbm_IsOpen(VAR f : DBMFile) : BOOLEAN;
BEGIN
        dbm_IsOpen := IsOpen(f.f);
END;

PROCEDURE dbm_Close(VAR f : DBMFile);
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        Seek(f.f, 0);
        BlockWrite(f.f, f.header, SizeOf(DBM_HDR));
        Close(f.f);
        FillChar(f, SizeOf(DBMFile), #0);
END;

PROCEDURE dbm_Free(VAR f : DBMFile; rec : LONGINT);
VAR     n : LONGINT;
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        WHILE rec <> 0 DO BEGIN
                _go(f, rec);
                n := ReadDWord(f.f);
                _go(f, rec);
                WriteDWord(f.f, f.header.next);
                WriteWord(f.f, 0);
                f.header.next := rec;
                rec := n;
        END;
END;

FUNCTION _alloc(VAR f : DBMFile) : LONGINT;
VAR     r : LONGINT;
BEGIN
        IF f.header.next <> 0 THEN BEGIN
                r := f.header.next;
                _go(f, r);
                f.header.next := ReadDWord(f.f);
        END ELSE BEGIN
                Inc(f.header.records);
                r := f.header.records;
        END;
        _go(f, r);
        _alloc := r;
END;

FUNCTION dbm_Size(VAR f : DBMFile; rec : LONGINT) : LONGINT;
VAR     r : LONGINT;
BEGIN
        r := 0;
        IF IsOpen(f.f) THEN BEGIN 
                WHILE rec <> 0 DO BEGIN
                        _go(f, rec);
                        rec := ReadDWord(f.f);
                        Inc(r, ReadWord(f.f));
                END;
        END;
        dbm_Size := r;
END;

PROCEDURE dbm_Get(VAR f : DBMFile; rec : LONGINT; VAR b; size : WORD);
VAR     p : PCHAR;
        g : WORD;
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        p := @b;
        WHILE (size <> 0) AND (rec <> 0) DO BEGIN
                _go(f, rec);
                rec := ReadDWord(f.f);
                g := ReadWord(f.f);
                IF g > size THEN g := size;
                BlockRead(f.f, p^, g);
                Dec(size, g);
                Inc(p, g);
        END;
END;

FUNCTION dbm_Add(VAR f : DBMFile; VAR b; size : WORD) : LONGINT;
VAR     root, prec, crec : LONGINT;
        p        : PCHAR;
        csize    : WORD;
        i        : INTEGER;
BEGIN
        root := 0;
        IF IsOpen(f.f) THEN BEGIN
                p := @b;
                prec := 0;
                WHILE size <> 0 DO BEGIN
                        crec := _alloc(f);
                        IF root = 0 THEN root := crec;
                        IF prec <> 0 THEN BEGIN
                                _go(f, prec);
                                WriteDWord(f.f, crec);
                        END;
                        csize := f.rblk_size;
                        IF csize > size THEN csize := size;
                        _go(f, crec);
                        WriteDWord(f.f, 0);
                        WriteWord(f.f, csize);
                        BlockWrite(f.f, p^, csize);
                        IF f.rblk_size > csize THEN BEGIN
                                FOR i := 1 TO f.rblk_size - csize DO WriteByte(f.f, 0);
                        END;
                        Dec(size, csize);
                        Inc(p, csize);
                        prec := crec;
                END;
        END;
        dbm_Add := root;
END;

PROCEDURE dbm_Put(VAR f : DBMFile; rec : LONGINT; VAR b; size : WORD);
VAR     crec : LONGINT;
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        _go(f, rec);
        crec := ReadDWord(f.f);
        _go(f, rec);
        WriteDWord(f.f, 0);
        WriteWord(f.f, 0);
        dbm_Free(f, crec);
        dbm_Free(f, rec);
        dbm_Add(f, b, size);
END;

FUNCTION dbm_GetRoot(VAR f : DBMFile):LONGINT;
BEGIN
        dbm_GetRoot := f.header.root;
END;

PROCEDURE dbm_SetRoot(VAR f : DBMFile; new_root : LONGINT);
BEGIN
        f.header.root := new_root;
END;

END.
