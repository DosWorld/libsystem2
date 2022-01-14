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
UNIT StrBin;

INTERFACE

{ StrAsLong - Parse signed Longint from string SRC from formats:
   ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄ¿
   ³ Format                   ³ Type      ³
   ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄ´
   ³ $XXX, 0xXXX, &hXXX, XXXh ³ Hex       ³
   ³ 0bXXX, &bXXX, XXXb       ³ Binary    ³
   ³ XXX                      ³ Decimal   ³
   ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÙ
   Sign chars "-" or "+" is supported, spaces - skip.
   Returns TRUE, if success }
FUNCTION StrAsLong(VAR src : STRING; VAR dst : LONGINT) : BOOLEAN;
{ Unsigned value }
FUNCTION ByteAsStr(b : BYTE) : STRING;
{ Signed value }
FUNCTION IntAsStr(i : INTEGER) : STRING;
{ Unsigned value }
FUNCTION WordAsStr(w : WORD) : STRING;
{ Signed value }
FUNCTION LongAsStr(l : LONGINT) : STRING;
{ Unsigned value }
FUNCTION ByteAsHex(b : BYTE) : STRING;
{ Unsigned value }
FUNCTION IntAsHex(i : INTEGER) : STRING;
{ Unsigned value }
FUNCTION LongAsHex(l : LONGINT) : STRING;

IMPLEMENTATION

CONST
BASE_2 = 2;
BASE_10 = 10;
BASE_16 = 16;

CHARS : STRING = '0123456789ABCDEF';

FUNCTION GetBase(VAR s : STRING; VAR i, len : INTEGER) : INTEGER;
VAR     cc    : CHAR;
        nc    : CHAR;
        base  : INTEGER;
BEGIN
        base := BASE_10;
        IF i <= len THEN cc := s[i] ELSE cc := #0;
        IF (i + 1) <= len THEN nc := UPCASE(s[i + 1]) ELSE nc := #0;
        IF cc = '$' THEN BEGIN
                base := BASE_16;
                Inc(i);
        END ELSE IF (cc = '0') AND (nc = 'X') THEN BEGIN
                base := BASE_16;
                Inc(i, 2);
        END ELSE IF (cc = '&') AND (nc = 'H') THEN BEGIN
                base := BASE_16;
                Inc(i, 2);
        END ELSE IF (cc = '0') AND (nc = 'B') THEN BEGIN
                base := BASE_2;
                Inc(i, 2);
        END ELSE IF (cc = '&') AND (nc = 'B') THEN BEGIN
                base := BASE_2;
                Inc(i, 2);
        END ELSE BEGIN
                cc := UPCASE(s[len]);
                IF cc = 'H' THEN BEGIN
                        base := BASE_16;
                        Dec(len);
                END ELSE IF cc = 'B' THEN BEGIN
                        base := BASE_2;
                        Dec(len);
                END;
        END;
        GetBase := base;
END;

FUNCTION Parse(base : INTEGER; VAR src : STRING; i, len : INTEGER; VAR dst : LONGINT) : BOOLEAN;
VAR     cc : CHAR;
        r  : LONGINT;
BEGIN
        r := 0;
        CASE base OF
        BASE_2: WHILE (i <= len) DO BEGIN
                        cc := src[i];
                        IF NOT (cc IN ['0','1']) THEN BREAK;
                        r := (r shl 1) OR (ORD(cc) - $30);
                        Inc(i);
                END;
        BASE_10:WHILE (i <= len) DO BEGIN
                        cc := src[i];
                        IF NOT (cc IN ['0'..'9']) THEN BREAK;
                        r := r * 10 OR (ORD(cc) - $30);
                        Inc(i);
                END;
        BASE_16:WHILE (i <= len) DO BEGIN
                        cc := UPCASE(src[i]);
                        IF cc IN ['0'..'9'] THEN
                                cc := CHR(ORD(cc) - $30)
                        ELSE IF cc IN ['A'..'F'] THEN
                                cc := CHR(ORD(cc) - $41 + 10)
                        ELSE BREAK;
                        r := (r shl 4) OR ORD(cc);
                        Inc(i);
                END;
        END;
        IF i > len THEN dst := r;
        Parse := i > len;
END;

FUNCTION StrAsLong(VAR src : STRING; VAR dst : LONGINT) : BOOLEAN;
VAR     err   : BOOLEAN;
        r     : BOOLEAN;
        base  : INTEGER;
        i     : INTEGER;
        neg   : BOOLEAN;
        len   : INTEGER;
        cc    : CHAR;
BEGIN
        r := FALSE;
        neg := FALSE;
        len := Length(src);
        i := 1;
        WHILE (len <> 0) AND (src[len] <= ' ') DO Dec(len);
        WHILE (i <= len) AND (src[i] <= ' ') DO Inc(i);
        IF i <= len THEN BEGIN
                IF src[i] = '-' THEN BEGIN neg := TRUE; Inc(i); END
                ELSE IF src[i] = '+' THEN Inc(i);
                WHILE (i <= len) AND (src[i] <= ' ') DO Inc(i);
        END;
        IF i <= len THEN BEGIN
                base := GetBase(src, i, len);
                WHILE (i <= len) AND (src[i] <= ' ') DO Inc(i);
                IF i <= len THEN BEGIN
                        r := Parse(base, src, i, len, dst);
                        IF r AND neg THEN dst := -dst;
                END;
        END;
        StrAsLong := r;
END;

FUNCTION ByteAsHex(b : BYTE) : STRING;
VAR     r : STRING[2];
        n : INTEGER;
BEGIN
        r[0] := #2;
        r[1] := CHARS[((b SHR 4) AND $0F) + 1];
        r[2] := CHARS[(b AND $0F) + 1];
        ByteAsHex := r;
END;

FUNCTION IntAsHex(i : INTEGER) : STRING;
VAR     r : STRING[4];
        n : INTEGER;
BEGIN
        r[0] := #4;
        n := 3;
        WHILE n >= 0 DO BEGIN
                r[4 - n] := CHARS[((i SHR (n SHL 2)) AND $0F) + 1];
                Dec(n);
        END;
        IntAsHex := r;
END;

FUNCTION LongAsHex(l : LONGINT) : STRING;
VAR     r : STRING[8];
        n : INTEGER;
BEGIN
        r[0] := #8;
        n := 7;
        WHILE n >= 0 DO BEGIN
                r[8 - n] := CHARS[((l SHR (n SHL 2)) AND $0F) + 1];
                Dec(n);
        END;
        LongAsHex := r;
END;

FUNCTION ByteAsStr(b : BYTE) : STRING;
VAR     r : STRING;
BEGIN
        Str(b, r);
        ByteAsStr := r;
END;

FUNCTION IntAsStr(i : INTEGER) : STRING;
VAR     r : STRING;
BEGIN
        Str(i, r);
        IntAsStr := r;
END;

FUNCTION WordAsStr(w : WORD) : STRING;
VAR     r : STRING;
BEGIN
        Str(w, r);
        WordAsStr := r;
END;

FUNCTION LongAsStr(l : LONGINT) : STRING;
VAR     r : STRING;
BEGIN
        Str(l, r);
        LongAsStr := r;
END;

END.