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
UNIT Arrays;

INTERFACE

TYPE

PARRAY = ^TARRAY;
TARRAY = RECORD
        item_size : WORD;
        size      : WORD;
        p         : PCHAR;
END;

PDICT_ENTRY = ^TDICT_ENTRY;
TDICT_ENTRY = RECORD
        next : PDICT_ENTRY;
        name : STRING[32];
        hash : WORD;
        b    : BYTE;
END;

PDICT = ^TDICT;
TDICT = RECORD
        item_size : WORD;
        root      : PDICT_ENTRY;
END;

FUNCTION array_new(item_size : WORD) : PARRAY;
PROCEDURE array_free(arr : PARRAY);

FUNCTION array_dim(arr : PARRAY; newsize : WORD) : BOOLEAN;
PROCEDURE array_get(arr : PARRAY; idx : WORD; VAR value);
PROCEDURE array_set(arr : PARRAY; idx : WORD; VAR value);
FUNCTION array_size(arr : PARRAY) : WORD;
FUNCTION array_max(arr : PARRAY) : WORD;

FUNCTION dict_new(item_size : WORD) : PDICT;
PROCEDURE dict_free(dictionary : PDICT);

FUNCTION dict_has(dictionary : PDICT; name : STRING) : BOOLEAN;
FUNCTION dict_get(dictionary : PDICT; name : STRING; VAR value) : BOOLEAN;
PROCEDURE dict_set(dictionary : PDICT; name : STRING; VAR value);

IMPLEMENTATION

USES Str;

FUNCTION array_max(arr : PARRAY) : WORD;
BEGIN
        array_max := 65535 DIV arr^.item_size;
END;

FUNCTION array_new(item_size : WORD) : PARRAY;
VAR     r : PARRAY;
BEGIN
        GetMem(r, SizeOf(TARRAY));
        r^.item_size := item_size;
        r^.size := 0;
        r^.p := NIL;
        array_new := r;
END;

PROCEDURE array_free(arr : PARRAY);
BEGIN
        IF arr^.p <> NIL THEN BEGIN
                FreeMem(arr^.p, arr^.item_size * arr^.size);
        END;
        FreeMem(arr, SizeOf(TARRAY));
END;

FUNCTION array_size(arr : PARRAY) : WORD;
BEGIN
        array_size := arr^.size;
END;

FUNCTION array_dim(arr : PARRAY; newsize : WORD) : BOOLEAN;
VAR     p  : PCHAR;
        ns : WORD;
        os : WORD;
        r  : BOOLEAN;
BEGIN
        r := FALSE;
        ns := newsize * arr^.item_size;
        IF newsize = 0 THEN BEGIN
                                IF arr^.p <> NIL THEN FreeMem(arr^.p, arr^.item_size * arr^.size);
                                arr^.p := NIL;
                                arr^.size := 0;
                                r := TRUE;
        END ELSE BEGIN
                GetMem(p, ns);
                IF p <> NIL THEN BEGIN
                        IF arr^.p <> NIL THEN BEGIN
                                os := arr^.item_size * arr^.size;
                                IF os <= ns THEN Move(arr^.p[0], p[0], os)
                                ELSE Move(arr^.p[0], p[0], ns);
                                FreeMem(arr^.p, os);
                        END;
                        arr^.p := p;
                        arr^.size := newsize;
                        r := TRUE;
                END;
        END;
        array_dim := r;
END;

PROCEDURE array_get(arr : PARRAY; idx : WORD; VAR value);
BEGIN
        IF idx < arr^.size THEN Move(arr^.p[arr^.item_size * idx], value, arr^.item_size);
END;

PROCEDURE array_set(arr : PARRAY; idx : WORD; VAR value);
BEGIN
        IF idx < arr^.size THEN Move(value, arr^.p[arr^.item_size * idx], arr^.item_size);
END;

FUNCTION dict_new(item_size : WORD) : PDICT;
VAR     r : PDICT;
BEGIN
        GetMem(r, SizeOf(TDICT));
        r^.item_size := item_size;
        r^.root := NIL;
        dict_new := r;
END;

PROCEDURE dict_free(dictionary : PDICT);
VAR     t : PDICT_ENTRY;
BEGIN
        WHILE dictionary^.root <> NIL DO BEGIN
                t := dictionary^.root;
                dictionary^.root := dictionary^.root^.next;
                FreeMem(t, SizeOf(TDICT_ENTRY) + dictionary^.item_size);
        END;
        FreeMem(dictionary, SizeOf(TDICT));
END;

FUNCTION _loopup(dictionary : PDICT; name : STRING) : PDICT_ENTRY;
VAR     t : PDICT_ENTRY;
        h : WORD;
BEGIN
        t := dictionary^.root;
        h := hcode(name);
        WHILE t <> NIL DO BEGIN
                IF t^.hash = h THEN
                        IF t^.name = name THEN BEGIN
                                BREAK;
                        END;
                t := t^.next;
        END;
        _loopup := t;
END;

FUNCTION dict_has(dictionary : PDICT; name : STRING) : BOOLEAN;
BEGIN
        dict_has := _loopup(dictionary, name) <> NIL;
END;

FUNCTION dict_get(dictionary : PDICT; name : STRING; VAR value) : BOOLEAN;
VAR     t : PDICT_ENTRY;
BEGIN
        t := _loopup(dictionary, name);
        IF t <> NIL THEN Move(t^.b, value, dictionary^.item_size);
        dict_get := t <> NIL;
END;

PROCEDURE dict_set(dictionary : PDICT; name : STRING; VAR value);
VAR     t : PDICT_ENTRY;
        h : WORD;
BEGIN
        t := _loopup(dictionary, name);
        IF t = NIL THEN BEGIN
                h := hcode(name);
                GetMem(t, SizeOf(TDICT_ENTRY) + dictionary^.item_size);
                t^.hash := h;
                t^.name := name;
                t^.next := dictionary^.root;
                dictionary^.root := t;
        END;
        Move(value, t^.b, dictionary^.item_size);
END;

END.

