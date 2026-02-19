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
{$I switches.inc}
UNIT ReadArc;

INTERFACE

USES System2;

TYPE
PFILE_ENTRY = ^FILE_ENTRY;
FILE_ENTRY=RECORD
        name   : STRING;
        hcode  : WORD;
        ofs    : LONGINT;
        csize  : LONGINT;
        ucsize : LONGINT;
        ctype  : WORD;
        next   : PFILE_ENTRY;
END;

{ funtion to operate with (loaded) files list }

FUNCTION FE_CREATE(next : PFILE_ENTRY; VAR name : STRING) : PFILE_ENTRY;
FUNCTION FE_FIND(root : PFILE_ENTRY; name : STRING; VAR dst : PFILE_ENTRY) : BOOLEAN;
PROCEDURE FE_DESTROY_ALL(fe : PFILE_ENTRY);

{ funtion to load files list from archive }

FUNCTION load_zip(VAR f : BFile) : PFILE_ENTRY;
FUNCTION load_ha(VAR f : BFile) : PFILE_ENTRY;
FUNCTION load_tar(VAR f : BFile) : PFILE_ENTRY;
FUNCTION load_any(VAR f : BFile) : PFILE_ENTRY;

{ ================================================
  Usage example:

uses System2, ReadArc;

var     n, i : PFILE_ENTRY;
        f    : BFile;
begin
        assign(f, 'test.tar');
        reset(f);
        n := load_tar(f);
        close(f);
        i := n;
        while i <> nil do begin
                system.writeln(i^.name,
                        , #9, i^.ofs:8
                        , #9, i^.csize:8);
                i := i^.next;
        end;
        FE_DESTROY_ALL(n);
end.
================================================== }

IMPLEMENTATION

USES Str;

CONST
ZIP_LSIG = $04034B50;
ZIP_CSIG = $02014b50;

TYPE
ZIP_LHEADER = RECORD
        sign       : LONGINT;
        ver        : WORD;
        gpflag     : WORD;
        compress   : WORD;
        time       : WORD;
        date       : WORD;
        crc32      : LONGINT;
        csize      : LONGINT;
        usize      : LONGINT;
        fnamelen   : WORD;
        extrafield : WORD;
END;

ZIP_CHEADER = RECORD
        sign       : LONGINT;
        vers       : WORD;
        vneeded    : WORD;
        gpflag     : WORD;
        compress   : WORD;
        time       : WORD;
        date       : WORD;
        crc32      : LONGINT;
        csize      : LONGINT;
        ucsize     : LONGINT;
        fnamelen   : WORD;
        extrafield : WORD;
        fcl        : WORD;
        dns        : WORD;
        ifa        : WORD;
        efa        : LONGINT;
        roolh      : LONGINT;
END;

CONST
HA_SIG = $4148;

TYPE
HA_CHEADER = RECORD
        sign   : WORD;
        count  : WORD;
END;

CONST
TAR_BLOCKSIZE = 512;
AR_SIGN : STRING[8] = '!<arch>'+#10;

PROCEDURE norm_name(VAR s : STRING);
VAR     i : INTEGER;
BEGIN
        upstr(s);
        FOR i := 1 TO Length(s) DO IF s[i] = '/' THEN s[i] := '\';
END;

FUNCTION FE_CREATE(next : PFILE_ENTRY; VAR name : STRING) : PFILE_ENTRY;
VAR     r : PFILE_ENTRY;
BEGIN
        GetMem(r, SizeOf(FILE_ENTRY));
        IF r <> NIL THEN BEGIN
                FillChar(r^, SizeOf(FILE_ENTRY), #0);
                r^.name := name;
                norm_name(r^.name);
                r^.hcode := hcode(r^.name);
                r^.next := next;
        END;
        FE_CREATE := r;
END;

PROCEDURE FE_DESTROY_ALL(fe : PFILE_ENTRY);
VAR     r : PFILE_ENTRY;
BEGIN
        WHILE fe <> NIL DO BEGIN
                r := fe;
                fe := fe^.next;
                FreeMem(r, SizeOf(FILE_ENTRY));
        END;
END;

FUNCTION FE_FIND(root : PFILE_ENTRY; name : STRING; VAR dst : PFILE_ENTRY) : BOOLEAN;
VAR     h : WORD;
BEGIN
        norm_name(name);
        h := hcode(name);
        WHILE root <> NIL DO BEGIN
                IF h = root^.hcode THEN IF root^.name = name THEN BREAK;
                root := root^.next;
        END;
        dst := root;
        FE_FIND := root <> NIL;
END;

FUNCTION load_zip(VAR f : BFile) : PFILE_ENTRY;
VAR     chdr    : ZIP_CHEADER;
        lhdr    : ZIP_LHEADER;
        s       : STRING;
        r, l, t : PFILE_ENTRY;
BEGIN
        r := NIL;
        l := NIL;

        IF IsOpen(f) THEN BEGIN
                Seek(f, 0);
                WHILE NOT Eof(f) DO BEGIN
                        BlockRead(f, lhdr, SizeOf(ZIP_LHEADER));
                        IF lhdr.sign <> ZIP_LSIG THEN BREAK;
                        BlockRead(f, s[1], lhdr.fnamelen);
                        s[0] := CHR(lhdr.fnamelen);
                        l := FE_CREATE(l, s);
                        l^.ofs := FilePos(f) + lhdr.extrafield;
                        Seek(f, l^.ofs + lhdr.csize);
                END;
                IF (NOT Eof(f)) AND (lhdr.sign = ZIP_CSIG) THEN BEGIN
                        Seek(f, FilePos(f) - SizeOf(ZIP_LHEADER));
                        WHILE NOT Eof(f) DO BEGIN
                                BlockRead(f, chdr, SizeOf(ZIP_CHEADER));
                                IF chdr.sign <> ZIP_CSIG THEN BREAK;
                                BlockRead(f, s[1], chdr.fnamelen);
                                s[0] := CHR(chdr.fnamelen);
                                IF FE_FIND(l, s, t) THEN BEGIN
                                        r := FE_CREATE(r, s);
                                        r^.ctype := chdr.compress;
                                        r^.ofs := t^.ofs;
                                        r^.csize := chdr.csize;
                                        r^.ucsize := chdr.ucsize;
                                END;
                                Seek(f, FilePos(f) + chdr.extrafield + chdr.fcl);
                        END;
                END;
        END;
        FE_DESTROY_ALL(l);
        load_zip := r;
END;

FUNCTION load_ha(VAR f : BFile) : PFILE_ENTRY;
VAR     r       : PFILE_ENTRY;
        chdr    : HA_CHEADER;
        i       : INTEGER;
        p       : LONGINT;
        s1, s2  : STRING;
        csize   : LONGINT;
        ucsize  : LONGINT;
        b       : BYTE;
BEGIN
        r := NIL;

        IF IsOpen(f) THEN BEGIN
                Seek(f, 0);
                i := 0;
                BlockRead(f, chdr, SizeOf(HA_CHEADER));
                IF chdr.sign = HA_SIG THEN BEGIN
                        WHILE (NOT Eof(f)) AND (i < chdr.count) DO BEGIN
                                b := ReadByte(f) AND $0F;
                                csize := ReadDword(f);
                                ucsize := ReadDword(f);
                                ReadDword(f);
                                ReadDword(f);
                                ReadAsciiz(f, s1);
                                ReadAsciiz(f, s2);
                                ReadWord(f);
                                ReadByte(f);
                                s1 := s1 + s2;
                                r := FE_CREATE(r, s1);
                                r^.ctype := b;
                                r^.ofs := FilePos(f);
                                r^.csize := csize;
                                r^.ucsize := ucsize;
                                Seek(f, r^.ofs + r^.csize);
                                Inc(i);
                        END;
                END;
        END;
        load_ha := r;
END;

FUNCTION load_tar(VAR f : BFile) : PFILE_ENTRY;
VAR     r       : PFILE_ENTRY;
        buf     : ARRAY[1..TAR_BLOCKSIZE] OF CHAR;
        fname   : STRING;
        fsize   : LONGINT;
        i       : INTEGER;
BEGIN
        r := NIL;
        IF IsOpen(f) THEN BEGIN
                Seek(f, 0);
                WHILE NOT Eof(f) DO BEGIN
                        BlockRead(f, buf, TAR_BLOCKSIZE);
                        fname := '';
                        i := 0;
                        WHILE i < 5 DO BEGIN
                                IF buf[i+258] = #0 THEN BREAK;
                                fname[i+1] := buf[i+258];
                                Inc(i);
                        END;
                        fname[0] := CHR(i);
                        IF fname <> 'ustar' THEN BREAK;
                        i := 1;
                        WHILE i < 101 DO BEGIN
                                IF buf[i] = #0 THEN BREAK;
                                fname[i] := buf[i];
                                Inc(i);
                        END;
                        fname[0] := CHR(i - 1);
                        fsize := 0;
                        i := 0;
                        WHILE i < 12 DO BEGIN
                                IF buf[i+125] = #0 THEN BREAK;
                                IF buf[i+125] IN ['0'..'7'] THEN BEGIN
                                        fsize := fsize * 8;
                                        Inc(fsize, ORD(buf[i+125]) - ORD('0'));
                                END;
                                Inc(i);
                        END;
                        r := FE_CREATE(r, fname);
                        r^.ofs := FilePos(f);
                        r^.csize := fsize;
                        r^.ucsize := fsize;
                        fsize := FilePos(f) + fsize;
                        IF (fsize MOD TAR_BLOCKSIZE) <> 0 THEN BEGIN
                                Inc(fsize, TAR_BLOCKSIZE - (fsize MOD TAR_BLOCKSIZE));
                        END;
                        Seek(f, fsize);
                        
                END;
        END;
        load_tar := r;
END;

FUNCTION load_any(VAR f : BFile) : PFILE_ENTRY;
VAR     r       : PFILE_ENTRY;
BEGIN
        r := NIL;
        IF r = NIL THEN r := load_tar(f);
        IF r = NIL THEN r := load_zip(f);
        IF r = NIL THEN r := load_ha(f);
        load_any := r;
END;

END.
