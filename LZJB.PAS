{ MIT License

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
{$A+,I-,S-,R-,D+,L+,Q-,F-,G-,O-,B-}
UNIT LZJb;

INTERFACE
USES System2;

{ return 0, if could not compress }
FUNCTION lzjb_compress_mem(src : PCHAR; src_len : WORD; dst : PCHAR; dst_len : WORD) : WORD;
FUNCTION lzjb_decompress_mem(src : PCHAR; src_len : WORD; dst : PCHAR) : WORD;

FUNCTION lzjb_compress(VAR src : BFILE; length : LONGINT; VAR dst : BFILE) : LONGINT;
FUNCTION lzjb_decompress(VAR src : BFILE; VAR dst : BFILE) : LONGINT;

FUNCTION lzjb_compress_file(src, dst : STRING) : LONGINT;
FUNCTION lzjb_decompress_file(src, dst : STRING) : LONGINT;

IMPLEMENTATION

CONST
BITS_IN_BYTE = 8;
MATCH_BITS   = 6;
MATCH_MIN    = 3;
MATCH_MAX    = (1 SHL MATCH_BITS) + (MATCH_MIN - 1);
OFFSET_MASK  = (1 SHL (16 - MATCH_BITS)) - 1;
LEMPEL_SIZE  = $400; { 1024 }
BUF_SIZE     = 8 * 1024;

TYPE
COMP_REC = RECORD
        osize : WORD;
        csize : WORD;
END;

FUNCTION lzjb_compress_mem(src : PCHAR; src_len : WORD; dst : PCHAR; dst_len : WORD) : WORD;
VAR     copymask, mlen       : INTEGER;
        offset, copymap, cpy : WORD;
        dst_pos, src_pos     : WORD;
        hashlo, hashhi       : WORD;
        lempel               : ARRAY [0..LEMPEL_SIZE - 1] OF WORD;
BEGIN
        copymap := 0;
        copymask := 1 SHL (BITS_IN_BYTE - 1);

        FillChar(lempel, SizeOf(lempel), #0);
        src_pos := 0;
        dst_pos := 0;
        WHILE src_pos < src_len DO BEGIN
                copymask := copymask  SHL 1;
                IF copymask  = (1 SHL BITS_IN_BYTE) THEN BEGIN
                        IF dst_pos >= (dst_len - 1 - 2 * BITS_IN_BYTE) THEN BEGIN
                                dst_pos := 0;
                                BREAK;
                        END;
                        copymask := 1;
                        copymap := dst_pos;
                        dst[dst_pos] := #0;
                        Inc(dst_pos);
                END;
                IF src_pos > (src_len - MATCH_MAX) THEN BEGIN
                        dst[dst_pos] := src[src_pos];
                        Inc(dst_pos);
                        Inc(src_pos);
                        CONTINUE;
                END;

                hashlo := (WORD(src[src_pos + 1]) SHL 8) OR WORD(src[src_pos + 2]);
                hashhi := WORD(src[src_pos]);
                Inc(hashlo, hashhi SHR 1);
                Inc(hashlo, (hashhi SHL 3) OR (hashlo SHR 5));
                hashlo := hashlo AND (LEMPEL_SIZE - 1);

                offset := (src_pos - lempel[hashlo]) AND OFFSET_MASK;
                lempel[hashlo] := src_pos;
                cpy := src_pos - offset;
                IF (src_pos >= offset)
                        AND (offset <> 0)
                        AND (src[src_pos] = src[cpy])
                        AND (src[src_pos + 1] = src[cpy + 1])
                        AND (src[src_pos + 2] = src[cpy + 2]) THEN BEGIN
                        dst[copymap] := CHR(ORD(dst[copymap]) OR copymask);
                        mlen := MATCH_MIN;
                        WHILE (mlen < MATCH_MAX) AND (src[src_pos + mlen] = src[cpy + mlen]) DO Inc(mlen);
                        dst[dst_pos] := Chr(
                                (WORD(mlen - MATCH_MIN) SHL (BITS_IN_BYTE - MATCH_BITS))
                                OR (offset SHR BITS_IN_BYTE));
                        Inc(dst_pos);
                        dst[dst_pos] := Chr(offset);
                        Inc(dst_pos);
                        Inc(src_pos, mlen);
                END ELSE BEGIN
                        dst[dst_pos] := src[src_pos];
                        Inc(dst_pos);
                        Inc(src_pos);
                END;
        END;
        lzjb_compress_mem := dst_pos;
END;

FUNCTION lzjb_decompress_mem(src : PCHAR; src_len : WORD; dst : PCHAR) : WORD;
VAR     copymap                       : BYTE;
        offset, cpy, src_pos, dst_pos : WORD;
        copymask, mlen                : INTEGER;
BEGIN
        src_pos := 0;
        dst_pos := 0;
        copymask := 1 SHL (BITS_IN_BYTE - 1);
        WHILE src_pos < src_len DO BEGIN
                copymask := copymask SHL 1;
                IF copymask = (1 SHL BITS_IN_BYTE) THEN BEGIN
                        copymask := 1;
                        copymap := Ord(src[src_pos]);
                        Inc(src_pos)
                END;
                IF (copymap AND copymask) <> 0 THEN BEGIN
                        mlen := (Ord(src[src_pos]) SHR (BITS_IN_BYTE - MATCH_BITS)) + MATCH_MIN;
                        offset := ((WORD(src[src_pos]) SHL BITS_IN_BYTE) OR WORD(src[src_pos + 1])) AND OFFSET_MASK;
                        Inc(src_pos, 2);
                        IF dst_pos < offset THEN BREAK;
                        cpy := dst_pos - offset;
                        WHILE mlen > 0 DO BEGIN
                                dst[dst_pos] := dst[cpy];
                                Inc(dst_pos);
                                Inc(cpy);
                                Dec(mlen);
                        END;
                END ELSE BEGIN
                        dst[dst_pos] := src[src_pos];
                        Inc(dst_pos);
                        Inc(src_pos);
                END;
        END;
        lzjb_decompress_mem := dst_pos;
END;

FUNCTION lzjb_compress(VAR src : BFILE; length : LONGINT; VAR dst : BFILE) : LONGINT;
VAR     rec   : COMP_REC;
        buf1  : ARRAY[0..BUF_SIZE - 1] OF CHAR;
        buf2  : ARRAY[0..BUF_SIZE - 1] OF CHAR;
        len   : WORD;
        count : LONGINT;
BEGIN
        count := 0;
        WHILE (length <> 0) AND (NOT Eof(src)) DO BEGIN
                IF length > BUF_SIZE THEN len := BUF_SIZE ELSE len := length;
                BlockRead(src, buf1, len);
                rec.osize := len;
                rec.csize := lzjb_compress_mem(@buf1, len, @buf2, len);
                IF rec.csize = 0 THEN BEGIN
                        BlockWrite(dst, rec, SizeOf(COMP_REC));
                        Inc(count, SizeOf(COMP_REC));
                        BlockWrite(dst, buf1, rec.csize);
                        Inc(count, rec.csize);
                END ELSE BEGIN
                        BlockWrite(dst, rec, SizeOf(COMP_REC));
                        Inc(count, SizeOf(COMP_REC));
                        BlockWrite(dst, buf2, rec.csize);
                        Inc(count, rec.csize);
                END;
                Dec(length, rec.osize);
        END;
        FillChar(rec, SizeOf(COMP_REC), #0);
        BlockWrite(dst, rec, SizeOf(COMP_REC));
        Inc(count, SizeOf(COMP_REC));

        lzjb_compress := count;
END;

FUNCTION lzjb_decompress(VAR src : BFILE; VAR dst : BFILE) : LONGINT;
VAR     rec   : COMP_REC;
        buf1  : ARRAY[0..BUF_SIZE - 1] OF CHAR;
        buf2  : ARRAY[0..BUF_SIZE - 1] OF CHAR;
        count : LONGINT;
BEGIN
        count := 0;
        WHILE NOT Eof(src) DO BEGIN
                BlockRead(src, rec, SizeOf(COMP_REC));
                IF (rec.osize = 0) AND (rec.csize = 0) THEN BREAK;
                BlockRead(src, buf1, rec.csize);
                IF rec.csize = 0 THEN BlockWrite(dst, buf1, rec.csize)
                ELSE BlockWrite(dst, buf2, lzjb_decompress_mem(@buf1, rec.csize, @buf2));
                Inc(count, rec.osize);
        END;
        lzjb_decompress := count;
END;

FUNCTION lzjb_compress_file(src, dst : STRING) : LONGINT;
VAR     i, o : BFILE;
        r    : LONGINT;
BEGIN
        r := 0;
        Assign(i, src); Reset(i);
        Assign(o, dst); ReWrite(o);
        IF IsOpen(i) AND IsOpen(o) THEN BEGIN
                r := FileSize(i);
                Seek(i, 0);
                r := lzjb_compress(i, r, o);
        END;
        Close(o);
        Close(i);
        lzjb_compress_file := r;
END;

FUNCTION lzjb_decompress_file(src, dst : STRING) : LONGINT;
VAR     i, o : BFILE;
        r    : LONGINT;
BEGIN
        r := 0;
        Assign(i, src); Reset(i);
        Assign(o, dst); ReWrite(o);
        IF IsOpen(i) AND IsOpen(o) THEN r := lzjb_decompress(i, o);
        Close(o);
        Close(i);
        lzjb_decompress_file := r;
END;

END.
