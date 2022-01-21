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
{$A+,I-,S-,R-,D-,L-,Q-,F-,G-,O-,B-}
UNIT DBU;

INTERFACE

USES System2;

TYPE
PDBUFile = ^DBUFile;
DBUFile=RECORD
        f          : PBFILE;
        idx        : PBFIle;
        first_free : WORD;
END;

PROCEDURE DBU_Reset(VAR d : DBUFile; VAR f, idx : BFile);
PROCEDURE DBU_ReWrite(VAR d : DBUFile; VAR f, idx : BFile);
FUNCTION DBU_IsOpen(VAR d : DBUFile) : BOOLEAN;
FUNCTION DBU_Create(VAR d : DBUFile) : WORD;
PROCEDURE DBU_Read(VAR d : DBUFile; h : WORD; ofs : DWORD; VAR mem; size : WORD);
PROCEDURE DBU_Write(VAR d : DBUFile; h : WORD; ofs : DWORD; VAR mem; size : WORD);
PROCEDURE DBU_Free(VAR d : DBUFile; h : WORD);
PROCEDURE DBU_Close(VAR d : DBUFile);

IMPLEMENTATION

CONST
BLOCK_SIZE_KB = 16;
BLOCK_SIZE = BLOCK_SIZE_KB * 1024;

PROCEDURE L_Append(VAR d : DBUFile);
VAR     i : INTEGER;
        n : ARRAY[1..1024] OF CHAR;
BEGIN
        FillChar(n, SizeOf(n), #0);
        FOR i := 1 TO BLOCK_SIZE_KB DO BlockWrite(d.f^, n, SizeOf(n));
END;

FUNCTION L_Size(VAR d : DBUFile) : WORD;
VAR     r1 : WORD;
        r2 : WORD;
BEGIN
        r1 := FileSize(d.f^) SHR 14;
        r2 := FileSize(d.idx^) SHR 2;
        IF r1 > r2 THEN L_Size := r2 ELSE L_Size := r1;
END;

PROCEDURE L_Seek(VAR d : DBUFile; page : WORD);
VAR     npage : WORD;
        sz    : WORD;
BEGIN
        sz := L_Size(d);
        IF (sz < page) THEN BEGIN
                Seek(d.f^, sz SHL 14);
                Seek(d.idx^, sz SHL 1);
                WHILE sz <= page DO BEGIN
                        L_Append(d);
                        WriteWord(d.idx^, d.first_free);
                        d.first_free := sz;
                        sz := L_Size(d);
                END;
        END;
        Seek(d.f^, page SHL 14);
        Seek(d.idx^, page SHL 1);
END;

PROCEDURE DBU_Reset(VAR d : DBUFile; VAR f, idx : BFile);
BEGIN
        FillChar(d, SizeOf(DBUFile), #0);
        d.f := @f;
        d.idx := @idx;
        IF (NOT EOF(d.f^)) AND (NOT EOF(d.idx^)) THEN BEGIN
                Seek(d.idx^, 0);
                d.first_free := ReadWord(d.idx^);
        END ELSE DBU_ReWrite(d, f, idx);
END;

FUNCTION DBU_IsOpen(VAR d : DBUFile) : BOOLEAN;
BEGIN
        DBU_IsOpen := IsOpen(d.f^) AND IsOpen(d.idx^);
END;

PROCEDURE DBU_ReWrite(VAR d : DBUFile; VAR f, idx : BFile);
BEGIN
        FillChar(d, SizeOf(DBUFile), #0);
        d.f := @f;
        d.idx := @idx;

        Seek(d.f^, 0);
        L_Append(d);
        Truncate(d.f^);

        Seek(d.idx^, 0);
        WriteWord(d.idx^, 0);
        Truncate(d.idx^);
END;

PROCEDURE DBU_Close(VAR d : DBUFile);
BEGIN
        Seek(d.idx^, 0);
        WriteWord(d.idx^, d.first_free);
        Close(d.f^);
        Close(d.idx^);
END;

FUNCTION DBU_Create(VAR d : DBUFile) : WORD;
VAR     r : WORD;
BEGIN
        IF d.first_free = 0 THEN L_Seek(d, L_Size(d) + 1);
        r := d.first_free;
        L_Seek(d, r);
        WriteWord(d.idx^, 0);
        Seek(d.idx^, FilePos(d.idx^) - SizeOf(WORD));
        DBU_Create := r;
END;


PROCEDURE DBU_Free(VAR d : DBUFile; h : WORD);
VAR     next : WORD;
BEGIN
        WHILE h <> 0 DO BEGIN
                next := GetWord(d.idx^, h SHL 1);
                SetWord(d.idx^, h SHL 1, d.first_free);
                d.first_free := h;
                h := next;
        END;
END;

FUNCTION next_page(VAR d : DBUFile; cpage : WORD) : WORD;
VAR     npage : WORD;
BEGIN
        Seek(d.idx^, cpage SHL 2);
        npage := ReadWord(d.idx^);
        IF npage = 0 THEN BEGIN
                IF d.first_free = 0 THEN L_Seek(d, (L_Size(d) + 1));
                npage := d.first_free;
                Seek(d.idx^, d.first_free SHL 1);
                d.first_free := ReadWord(d.idx^);
                Seek(d.idx^, d.first_free SHL 1);
                WriteWord(d.idx^, 0);
                Seek(d.idx^, cpage SHL 1);
                WriteWord(d.idx^, npage);
        END;
        next_page := npage;
END;

PROCEDURE DBU_Write(VAR d : DBUFile; h : WORD; ofs : DWORD; VAR mem; size : WORD);
VAR     page : WORD;
        pofs : WORD;
        p    : PCHAR;
        s    : WORD;
BEGIN
        page := ofs SHR 14;
        pofs := ofs AND $3FFF;
        p := @mem;
        WHILE page <> 0  DO BEGIN
                h := next_page(d, h);
                Dec(page);
        END;
        WHILE size <> 0 DO BEGIN
                L_Seek(d, h);
                s := size;
                IF s > (BLOCK_SIZE - pofs) THEN s := BLOCK_SIZE - pofs;
                IF pofs <> 0 THEN Seek(d.f^, FilePos(d.f^) + pofs);
                BlockWrite(d.f^, p[0], s);
                pofs := 0;
                Dec(size, s);
                Inc(p, s);
                h := next_page(d, h);
        END;
END;

PROCEDURE DBU_Read(VAR d : DBUFile; h : WORD; ofs : DWORD; VAR mem; size : WORD);
VAR     page : WORD;
        pofs : WORD;
        p    : PCHAR;
        s    : WORD;
        r    : WORD;
BEGIN
        page := ofs SHR 14;
        pofs := ofs AND $3FFF;
        p := @mem;
        WHILE page <> 0  DO BEGIN
                h := next_page(d, h);
                Dec(page);
        END;
        WHILE size <> 0 DO BEGIN
                L_Seek(d, h);
                s := size;
                IF s > (BLOCK_SIZE - pofs) THEN s := BLOCK_SIZE - pofs;
                IF pofs <> 0 THEN Seek(d.f^, FilePos(d.f^) + pofs);
                BlockRead(d.f^, p[0], s);
                pofs := 0;
                Dec(size, s);
                Inc(p, s);
                h := next_page(d, h);
        END;
END;

END.