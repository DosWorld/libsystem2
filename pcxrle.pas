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
{$I switches.inc}
UNIT pcxrle;

INTERFACE

FUNCTION RLE_COMPRESS(src: PCHAR; len: WORD; dst: PCHAR): WORD;
FUNCTION RLE_DECOMPRESS(src: PCHAR; len: WORD; dst: PCHAR): WORD;

IMPLEMENTATION

FUNCTION RLE_COMPRESS(src: PCHAR; len: WORD; dst: PCHAR): WORD;
VAR
    dstPtr: WORD;
    count: BYTE;
    c     : CHAR;
BEGIN
    dstPtr := ofs(dst^);
    WHILE len <> 0 DO BEGIN
        count := 1;
        c := src^;
        WHILE (count <= len) AND (c = src[count]) AND (count < 63) DO INC(count);
        IF (count > 1) OR ((ORD(c) AND $C0) = $C0) THEN BEGIN
            dst^ := CHR($C0 OR count);
            INC(dst);
            dst^ := c;
            INC(dst);
        END ELSE BEGIN
            dst^ := c;
            INC(dst);
        END;
        INC(src, count);
        DEC(len, count);
    END;
    RLE_COMPRESS := ofs(dst^) - dstPtr;
END;

FUNCTION RLE_DECOMPRESS(src: PCHAR; len: WORD; dst: PCHAR): WORD;
VAR
    dstPtr: WORD;
    count: BYTE;
    c : CHAR;
BEGIN
    dstPtr := ofs(dst^);
    WHILE len <> 0 DO BEGIN
        c := src^;
        IF (ORD(c) AND $C0) = $C0 THEN BEGIN
            count := ORD(c) AND $3F;
            INC(src);
            DEC(len);
            FillChar(dst^, count, src^);
        END ELSE BEGIN
            dst^ := c;
            count := 1;
        END;
        INC(src);
        DEC(len);
        INC(dst, count);
    END;
    RLE_DECOMPRESS := ofs(dst^) - dstPtr;
END;

END.
