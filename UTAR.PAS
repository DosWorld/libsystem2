{  MIT License

Copyright (c) 2024 Viacheslav Komenda

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
UNIT UTAR;

INTERFACE

(* Read/Write .tar file.

   File read example:

    VAR f : TAR_FILE; fname : STRING; fsize : LONGINT;
    BEGIN
        Assign(f, 'hello.tar');
        Reset(f, 1);
        WHILE utar.Find(f, fname, fsize) DO BEGIN
			WriteLn(fname, ' ', fsize);
			Seek(f, FilePos(f) + fsize);
        END;
        Close(f);
    END;

   File write example:

    VAR f : TAR_FILE; str : STRING;
    BEGIN
        Assign(f, 'hello.tar');
        ReWrite(f, 1);

		{ hello.txt }
		str := 'Hello, world!';
		utar.Add(f, 'hello.txt', Length(str));
		BlockWrite(f, str[1], Length(str));

		{ another.txt }
		str := 'Hello, another world!';
		utar.Add(f, 'another.txt', Length(str));
		BlockWrite(f, str[1], Length(str));

		{ close file }
		utar.Finish(f);
        Close(f);
    END; *)

TYPE TAR_FILE = FILE;
(* Find next file. Before call: file position at header start. After, - at begin of content *)
FUNCTION Find(VAR f : TAR_FILE; VAR filename : STRING; VAR filesize : LONGINT) : BOOLEAN;
(* Add one more header for file. After it, you can write content *)
PROCEDURE Add(VAR f : TAR_FILE; filename : STRING; filesize : LONGINT);
(* Finallize, need before close .tar file*)
PROCEDURE Finish(VAR f : TAR_FILE);

IMPLEMENTATION

CONST
TAR_BLOCKSIZE = 512;
TAR_OWNER     = 'root';
TAR_USTAR     = 'ustar  ';
TAR_FILEMODE  = '0000640';
TAR_UGID      = '0000000';
TAR_DATETIME  = '00000000000';

TYPE
TAR_BLOCK = ARRAY[1..TAR_BLOCKSIZE] OF CHAR;

(* ----------------------------------------------------------------------------------- *)

PROCEDURE WriteAlignment(VAR f : TAR_FILE);
VAR buf : TAR_BLOCK;
    p   : INTEGER;
BEGIN
    p := FilePos(f) MOD TAR_BLOCKSIZE;
    IF p <> 0 THEN BEGIN
        FillChar(buf, TAR_BLOCKSIZE, #0);
        BlockWrite(f, buf, TAR_BLOCKSIZE - p);
    END;
END;

FUNCTION Int2Oct(i : LONGINT) : STRING;
VAR r : STRING;
    c : CHAR;
BEGIN
    c := CHR((i mod 8) + ORD('0'));
    i := i DIV 8;
    IF i <> 0 THEN r := Int2Oct(i) ELSE r := '';
    Int2Oct := r + c;
END;

PROCEDURE SetStrMem(VAR buf : TAR_BLOCK; ofs : INTEGER; s : STRING);
BEGIN
    Move(s[1], buf[ofs], Length(s));
END;

FUNCTION GetStrMem(VAR buf : TAR_BLOCK; ofs, len : INTEGER) : STRING;
VAR s : STRING;
BEGIN
	s := '';
	WHILE (len > 0) AND (buf[ofs] <> #0) DO BEGIN
		s := s + buf[ofs];
		INC(ofs);
		DEC(len);
	END;
	GetStrMem := s;
END;

FUNCTION lpad(s : STRING; len : INTEGER) : STRING;
BEGIN
	WHILE Length(s) < len DO s := '0' + s;
	lpad := s;
END;

FUNCTION CheckSum(VAR buf : TAR_BLOCK) : INTEGER;
VAR r : INTEGER;
	i : INTEGER;
BEGIN
	r := 0;
    FOR i := 1 TO TAR_BLOCKSIZE DO INC(r, ORD(buf[i]));
	CheckSum := r;
END;

(* ----------------------------------------------------------------------------------- *)

FUNCTION Find(VAR f : TAR_FILE; VAR filename : STRING; VAR filesize : LONGINT) : BOOLEAN;
VAR r   : BOOLEAN;
    buf : TAR_BLOCK;
    str : STRING;
    i   : INTEGER;
    p   : LONGINT;
BEGIN
    r := FALSE;
    p := FilePos(f);
    i := p MOD TAR_BLOCKSIZE;
    IF i <> 0 THEN Seek(f, p + (TAR_BLOCKSIZE - i));
    BlockRead(f, buf, TAR_BLOCKSIZE);
    IF GetStrMem(buf, 258, 7) = TAR_USTAR THEN BEGIN
		filename := GetStrMem(buf, 1, 100);
		str := GetStrMem(buf, 125, 12);
		filesize := 0;
		i := 1;
		WHILE (i <= Length(str)) AND (str[i] IN ['0'..'7']) DO BEGIN
			filesize := filesize * 8;
			INC(filesize, ORD(str[i]) - ORD('0'));
			INC(i);
		END;
		r := TRUE;
    END ELSE Seek(f, p);
    Find := r;
END;

PROCEDURE Add(VAR f : TAR_FILE; filename : STRING; filesize : LONGINT);
VAR buf     : TAR_BLOCK;
BEGIN
    FillChar(buf, TAR_BLOCKSIZE, #0);

    SetStrMem(buf, 1, filename);
    SetStrMem(buf, 125, lpad(Int2Oct(filesize), 11));
    SetStrMem(buf, 101, TAR_FILEMODE);
    SetStrMem(buf, 109, TAR_UGID);
    SetStrMem(buf, 117, TAR_UGID);
    SetStrMem(buf, 137, TAR_DATETIME);
    SetStrMem(buf, 258, TAR_USTAR);
    SetStrMem(buf, 266, TAR_OWNER);
    SetStrMem(buf, 298, TAR_OWNER);
    FillChar(buf[149], 8, ' ');
    SetStrMem(buf, 149, lpad(Int2Oct(CheckSum(buf)), 8));

    WriteAlignment(f);
    BlockWrite(f, buf, TAR_BLOCKSIZE);
END;

PROCEDURE Finish(VAR f : TAR_FILE);
VAR buf : TAR_BLOCK;
BEGIN
    FillChar(buf, TAR_BLOCKSIZE, #0);

    WriteAlignment(f);
    BlockWrite(f, buf, TAR_BLOCKSIZE);
    BlockWrite(f, buf, TAR_BLOCKSIZE);
END;

END.
