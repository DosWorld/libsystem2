{ MIT License

Copyright (c) 2025 Viacheslav Komenda

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
{$A-,I-,S-,R-,D+,L+,Q-,F-,G-,O-,B-}
UNIT ar;

INTERFACE

USES system2, dynarr;

TYPE
ARFILE = BFILE;

PArFileEntry = ^TArFileEntry;
TArFileEntry = RECORD
    name    : STRING[16];
    ofs     : LONGINT;
    size    : LONGINT;
END;

FUNCTION IsArFile(VAR f : ARFILE; ofs : LONGINT) : BOOLEAN;
PROCEDURE ReadDir(VAR FileArray : TArray; VAR f : ARFILE; ofs : LONGINT);
FUNCTION Find(VAR FileArray : TArray; name : STRING) : PArFileEntry;
PROCEDURE Create(VAR f : ARFILE);
PROCEDURE AddHeader(VAR f : ARFILE; name : STRING; len : LONGINT);

IMPLEMENTATION

USES Memframe;

TYPE
ArFileEntry = RECORD
        name     : ARRAY[1..16] OF CHAR;
        mod_time : ARRAY[1..12] OF CHAR;
        owner    : ARRAY[1..6] OF CHAR;
        group    : ARRAY[1..6] OF CHAR;
        attr     : ARRAY[1..8] OF CHAR;
        size     : ARRAY[1..10] OF CHAR;
        ending   : WORD;
END;

FUNCTION IsArFile(VAR f : ARFILE; ofs : LONGINT) : BOOLEAN;
VAR
    s : STRING;
BEGIN
    Seek(f, ofs);
    BlockRead(f, s[1], 8);
    s[0] := #8;
    IsArFile := s = ('!<arch>' + #$0A);
END;

PROCEDURE ReadDir(VAR FileArray : TArray; VAR f : ARFILE; ofs : LONGINT);
VAR
    c    : TArFileEntry;
    w    : WORD;
    frec : ArFileEntry;
BEGIN
        dynarr.Init(FileArray, SizeOf(c), NIL);
        Seek(f, ofs + 8);
        WHILE NOT EOF(f) DO BEGIN
                FillChar(c, SizeOf(c), #0);
                w := BlockRead(f, frec, SizeOf(frec));
                IF w <> SizeOf(frec) THEN BREAK;
                IF frec.ending <> $0A60 THEN BREAK;
                c.name[0] := #16;
                Move(frec.name, c.name[1], 16);
                FOR w := 1 TO 16 DO BEGIN
                        c.name[w] := upcase(c.name[w]);
                        IF c.name[w] = '/' THEN c.name[w] := '\'
                        ELSE IF c.name[w] < ' ' THEN c.name[w] := ' ';
                END;
                WHILE (c.name[0] <> #0) AND (c.name[ORD(c.name[0])] IN [' ', '\']) DO DEC(c.name[0]);
                c.ofs := FilePos(f);
                c.size := 0;
                FOR w := 1 TO 10 DO BEGIN
                        IF frec.size[w] IN ['0'..'9'] THEN BEGIN
                        c.size := c.size * 10 + (ORD(frec.size[w]) - ORD('0'));
                        END;
                END;
                Seek(f, FilePos(f) + c.size);
                IF (FilePos(f) AND 1) <> 0 THEN Seek(f, FilePos(f) + 1);
                dynarr.Add(FileArray, c);
        END;
END;

FUNCTION Find(VAR FileArray : TArray; name : STRING) : PArFileEntry;
VAR
        n : STRING[16];
        i : INTEGER;
        r : POINTER;
        rec : PArFileEntry;
BEGIN
        r := NIL;
        n := name;
        FOR i := 1 TO ORD(n[0]) DO n[i] := upcase(n[i]);
        i := 0;
        WHILE i < dynarr.GetLength(FileArray) DO BEGIN
                rec := dynarr.GetPtr(FileArray, i);
                IF rec^.name = n THEN BEGIN r := rec; BREAK; END;
                INC(i);
        END;
        Find := r;
END;

PROCEDURE Create(VAR f : ARFILE);
VAR
    s : STRING;
BEGIN
        s := '!<arch>' + #$0A;
        BlockWrite(f, s[1], 8);
        Truncate(f);
END;

PROCEDURE AddHeader(VAR f : ARFILE; name : STRING; len : LONGINT);
VAR
    frec    : ArFileEntry;
    s       : STRING;
    i       : INTEGER;
BEGIN
        IF (FilePos(f) AND 1) <> 0 THEN BEGIN
                i := 0;
                BlockWrite(f, i, 1);
        END;
        name := name + '/';
        FillChar(frec, SizeOf(frec), #0);
        frec.ending := $0A60;
        i := Length(name);
        IF i > 16 THEN i := 16;
        Move(name[1], frec.name, i);
        Str(len, s);
        Move(s[1], frec.size, Length(s));
        BlockWrite(f, frec, SizeOf(frec));
END;

END.
