{
 MIT License

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

{ Simple cache implementation }

{$A+,I-,S-,R-,D-,L-,Q-,F-,G-,O-,B-}
UNIT ExCache;

INTERFACE

CONST
EXCACHE_ITEM_COUNT = 16;

TYPE
TEXCACHE_ITEM = RECORD
        recno   : LONGINT;
        page    : WORD;
        count   : WORD;
        is_busy : BOOLEAN;
END;

PEXCACHE = ^TEXCACHE;
TEXCACHE = RECORD
        h     : WORD;
        size  : WORD;
        items : ARRAY[1..EXCACHE_ITEM_COUNT] OF TEXCACHE_ITEM;
END;

FUNCTION excache_create(size : WORD) : PEXCACHE;
PROCEDURE excache_free(c : PEXCACHE);
FUNCTION excache_is_full(c : PEXCACHE) : BOOLEAN;

FUNCTION excache_get(c : PEXCACHE; recno : LONGINT; VAR b; VAR count : WORD) : BOOLEAN;
FUNCTION excache_put(c : PEXCACHE; recno : LONGINT; VAR b; count : WORD) : BOOLEAN;
PROCEDURE excache_revoke(c : PEXCACHE; recno : LONGINT);
PROCEDURE excache_truncate(c : PEXCACHE; recno : LONGINT; count : WORD);
FUNCTION excache_size(c : PEXCACHE) : WORD;

IMPLEMENTATION

USES EXms;

FUNCTION excache_create(size : WORD) : PEXCACHE;
VAR     r    : PEXCACHE;
        h    : WORD;
BEGIN
        r := NIL;
        IF exms_check_driver THEN BEGIN
                IF size > EXCACHE_ITEM_COUNT THEN size := EXCACHE_ITEM_COUNT;
                h := exms_malloc(size);
                IF h <> 0 THEN BEGIN
                        GetMem(r, SizeOf(TEXCACHE));
                        FillChar(r^, SizeOf(TEXCACHE), #0);
                        r^.h := h;
                        r^.size := size;
                        FOR h := 1 TO r^.size DO r^.items[h].page := h - 1;
                END;
        END;
        excache_create := r;
END;

PROCEDURE excache_free(c : PEXCACHE);
BEGIN
        IF c = NIL THEN EXIT;
        IF c^.h <> 0 THEN exms_free(c^.h);
        c^.h := 0;
        FreeMem(c, SizeOf(TEXCACHE));
END;

PROCEDURE make_top(c : PEXCACHE; page : WORD);
VAR     item : TEXCACHE_ITEM;
        i    : INTEGER;
BEGIN
        IF page = 1 THEN EXIT;
        item := c^.items[page];
        i := page;
        WHILE i <> 1 DO BEGIN
                c^.items[i] := c^.items[i - 1];
                Dec(i);
        END;
        c^.items[1] := item;
END;

FUNCTION lookup_recno(c : PEXCACHE; recno : LONGINT) : BOOLEAN;
VAR     i : INTEGER;
        r : BOOLEAN;
BEGIN
        r := FALSE;
        i := 1;
        WHILE i <= c^.size DO BEGIN
                IF c^.items[i].is_busy
                        AND (c^.items[i].recno = recno) THEN BEGIN
                        make_top(c, i);
                        r := TRUE;
                        BREAK;
                END;
                Inc(i);
        END;
        lookup_recno := r;
END;

FUNCTION lookup_free(c : PEXCACHE) : INTEGER;
VAR     i, r : INTEGER;
BEGIN
        r := c^.size;
        i := 1;
        WHILE i <= r DO BEGIN
                IF NOT c^.items[i].is_busy THEN BEGIN
                        r := i;
                        BREAK;
                END;
                Inc(i);
        END;
        lookup_free := r;
END;

FUNCTION excache_get(c : PEXCACHE; recno : LONGINT; VAR b; VAR count : WORD) : BOOLEAN;
VAR     r : BOOLEAN;
BEGIN
        r := FALSE;
        IF c <> NIL THEN BEGIN
                IF c^.h <> 0 THEN r := lookup_recno(c, recno);
        END;
        IF r THEN BEGIN
                exms_copy(c^.h, c^.items[1].page, b, EXT2DOS);
                count := c^.items[1].count;
                c^.items[1].is_busy := FALSE;
        END;
        excache_get := r;
END;

FUNCTION excache_put(c : PEXCACHE; recno : LONGINT; VAR b; count : WORD) : BOOLEAN;
BEGIN
        IF c = NIL THEN excache_put := FALSE
        ELSE IF c^.h = 0 THEN excache_put := FALSE
        ELSE BEGIN
                IF NOT lookup_recno(c, recno) THEN make_top(c, lookup_free(c));
                c^.items[1].recno := recno;
                c^.items[1].count := count;
                c^.items[1].is_busy := TRUE;
                exms_copy(c^.h, c^.items[1].page, b, DOS2EXT);
                excache_put := TRUE;
        END;
END;

PROCEDURE excache_revoke(c : PEXCACHE; recno : LONGINT);
VAR     i  : INTEGER;
BEGIN
        IF c = NIL THEN EXIT;
        IF c^.h = 0 THEN EXIT;
        FOR i := 1 TO c^.size DO BEGIN
                IF c^.items[i].is_busy AND (c^.items[i].recno = recno) THEN BEGIN
                        c^.items[i].is_busy := FALSE;
                        EXIT;
                END;
        END;
        
END;

PROCEDURE excache_truncate(c : PEXCACHE; recno : LONGINT; count : WORD);
VAR     i  : INTEGER;
BEGIN
        IF c = NIL THEN EXIT;
        IF c^.h = 0 THEN EXIT;

        i := 1;
        WHILE i <= c^.size DO BEGIN
                IF c^.items[i].is_busy THEN BEGIN
                        IF c^.items[i].recno = recno THEN c^.items[i].count := count
                        ELSE IF c^.items[i].recno > recno THEN c^.items[i].is_busy := FALSE;
                END;
                Inc(i);
        END;
END;

FUNCTION excache_is_full(c : PEXCACHE) : BOOLEAN;
VAR     i : INTEGER;
        r : BOOLEAN;
BEGIN
        IF c <> NIL THEN BEGIN
                r := TRUE;
                i := 1;
                WHILE (i <= c^.size) AND r DO BEGIN
                        r := r AND c^.items[i].is_busy;
                        Inc(i);
                END;
                excache_is_full := r;
        END ELSE excache_is_full := TRUE;
END;

FUNCTION excache_size(c : PEXCACHE) : WORD;
BEGIN
        IF c = NIL THEN excache_size := 0 ELSE excache_size := c^.size;
END;

END.
