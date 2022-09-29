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
UNIT DBB;
{ =========================================================================
  This is unit implements dbb files (like a .dbt) - but fixed size blocks,
  has "garbage collection" (free blocks will be reused).
  ========================================================================= }
INTERFACE

USES System2;

TYPE
DBB_HDR = RECORD
        sign       : WORD;
        next       : LONGINT;
        records    : LONGINT;
        root       : LONGINT;
        size       : WORD;
END;

DBBFile = RECORD
        f          : BFILE;
        header     : DBB_HDR;
END;

PROCEDURE dbb_reset(VAR f : DBBFile; fname : STRING; blk_size : WORD);
PROCEDURE dbb_rewrite(VAR f : DBBFile; fname : STRING; blk_size : WORD);
PROCEDURE dbb_rewrite_temp(VAR f : DBBFile; blk_size : WORD);

FUNCTION dbb_isopen(VAR f : DBBFile) : BOOLEAN;

FUNCTION dbb_add(VAR f : DBBFile; VAR b) : LONGINT;
PROCEDURE dbb_put(VAR f : DBBFile; rec : LONGINT; VAR b);
PROCEDURE dbb_get(VAR f : DBBFile; rec : LONGINT; VAR b);

PROCEDURE dbb_free(VAR f : DBBFile; rec : LONGINT);
PROCEDURE dbb_close(VAR f : DBBFile);

FUNCTION dbb_getroot(VAR f : DBBFile):LONGINT;
PROCEDURE dbb_setroot(VAR f : DBBFile; new_root : LONGINT);

IMPLEMENTATION

TYPE
PLONGINT = ^LONGINT;

CONST
DBB_SIGN     = $4244;
DBB_HDR_SIZE = SizeOf(DBB_HDR);

FUNCTION dbb_go(VAR f : DBBFile; recno : LONGINT) : LONGINT;
VAR     r : LONGINT;
BEGIN
        r := DBB_HDR_SIZE + (recno - 1) * f.header.size;
        Seek(f.f, DBB_HDR_SIZE + (recno - 1) * f.header.size);
        dbb_go := r;
END;

PROCEDURE dbb_reset(VAR f : DBBFile; fname : STRING; blk_size : WORD);
BEGIN
        FillChar(f, SizeOf(DBBFile), #0);
        Assign(f.f, fname);
        Reset(f.f);
        IF NOT IsOpen(f.f) THEN BEGIN
                dbb_rewrite(f, fname, blk_size);
                EXIT;
        END;
        IF SizeOf(DBB_HDR) <> BlockRead(f.f, f.header, SizeOf(DBB_HDR)) THEN BEGIN
                Close(f.f);
                dbb_rewrite(f, fname, blk_size);
                EXIT;
        END;
        IF (f.header.sign <> DBB_SIGN) OR (f.header.size <> blk_size) THEN BEGIN
                Close(f.f);
                dbb_rewrite(f, fname, blk_size);
        END;
END;

PROCEDURE _dbb_rewrite(VAR f : DBBFile; blk_size : WORD);
BEGIN
        IF IsOpen(f.f) THEN BEGIN
                f.header.sign := DBB_SIGN;
                f.header.next := 0;
                f.header.records := 0;
                f.header.root := 0;
                f.header.size := blk_size;
                Seek(f.f, 0);
                BlockWrite(f.f, f.header, DBB_HDR_SIZE);
        END;
END;

PROCEDURE dbb_rewrite(VAR f : DBBFile; fname : STRING; blk_size : WORD);
BEGIN
        FillChar(f, SizeOf(DBBFile), #0);
        Assign(f.f, fname);
        ReWrite(f.f);
        _dbb_rewrite(f, blk_size);
END;

PROCEDURE dbb_rewrite_temp(VAR f : DBBFile; blk_size : WORD);
BEGIN
        FillChar(f, SizeOf(DBBFile), #0);
        ReWriteTemp(f.f);
        _dbb_rewrite(f, blk_size);
END;

FUNCTION dbb_isopen(VAR f : DBBFile) : BOOLEAN;
BEGIN
        dbb_isopen := IsOpen(f.f);
END;

PROCEDURE dbb_close(VAR f : DBBFile);
BEGIN
        IF NOT IsOpen(f.f) THEN EXIT;
        Seek(f.f, 0);
        BlockWrite(f.f, f.header, DBB_HDR_SIZE);
        Close(f.f);
        FillChar(f, SizeOf(DBBFile), #0);
END;

PROCEDURE dbb_free(VAR f : DBBFile; rec : LONGINT);
BEGIN
        IF (NOT IsOpen(f.f)) OR (rec = 0) THEN EXIT;
        dbb_go(f, rec);
        WriteDWord(f.f, f.header.next);
        f.header.next := rec;
END;

FUNCTION dbb_alloc(VAR f : DBBFile) : LONGINT;
VAR     r : LONGINT;
BEGIN
        IF f.header.next <> 0 THEN BEGIN
                r := f.header.next;
                dbb_go(f, r);
                f.header.next := ReadDWord(f.f);
        END ELSE BEGIN
                Inc(f.header.records);
                r := f.header.records;
        END;
        dbb_alloc := r;
END;

PROCEDURE dbb_get(VAR f : DBBFile; rec : LONGINT; VAR b);
BEGIN
        IF (NOT IsOpen(f.f)) OR (rec = 0) THEN EXIT;
        dbb_go(f, rec);
        BlockRead(f.f, b, f.header.size);
END;

FUNCTION dbb_add(VAR f : DBBFile; VAR b) : LONGINT;
VAR     res : LONGINT;
BEGIN
        res := 0;
        IF IsOpen(f.f) THEN BEGIN
                res := dbb_alloc(f);
                dbb_go(f, res);
                BlockWrite(f.f, b, f.header.size);
        END;
        dbb_add := res;
END;

PROCEDURE dbb_put(VAR f : DBBFile; rec : LONGINT; VAR b);
BEGIN
        IF (NOT IsOpen(f.f)) OR (rec = 0) THEN EXIT;
        dbb_go(f, rec);
        BlockWrite(f.f, b, f.header.size);
END;

FUNCTION dbb_getroot(VAR f : DBBFile):LONGINT;
BEGIN
        dbb_getroot := f.header.root;
END;

PROCEDURE dbb_setroot(VAR f : DBBFile; new_root : LONGINT);
BEGIN
        f.header.root := new_root;
END;

END.
