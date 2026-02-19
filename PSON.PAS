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
{$I switches.inc}
UNIT pson;

INTERFACE

CONST

PSON_EOF   = #1;
PSON_CHAR  = #2;
PSON_INT   = #4;
PSON_REAL  = #5;
PSON_STR   = #6;
PSON_OBJ   = #7;

TYPE

PSON_KEY_TYPE   = STRING;
PSON_PTR_TYPE   = PCHAR;

PSON_CHAR_TYPE  = CHAR;
PSON_INT_TYPE   = LONGINT;
PSON_REAL_TYPE  = SINGLE;
PSON_STR_TYPE   = STRING;

{$IFDEF PSON16}
        {$DEFINE _PSON_TYPE}
        PSON_LEN_TYPE = WORD;
{$ENDIF}
{$IFDEF PSON32}
        {$DEFINE _PSON_TYPE}
        PSON_LEN_TYPE = LONGINT;
{$ENDIF}
{$IFNDEF _PSON_TYPE}
        {$UNDEF _PSON_SEL}
        {$IFNDEF _PSON_SEL}
                {$IFDEF CPU16}
                        {$DEFINE PSON16}
                        {$DEFINE _PSON_SEL}
                {$ENDIF}
        {$ENDIF}
        {$IFDEF CPU32}
                {$DEFINE PSON32}
                {$DEFINE _PSON_SEL}
        {$ENDIF}
        {$IFNDEF _PSON_SEL}
                {$DEFINE PSON16}
                {$DEFINE _PSON_SEL}
        {$ENDIF}
{$ENDIF}
{$IFNDEF _PSON_TYPE}
        {$IFDEF PSON16}
                {$DEFINE _PSON_TYPE}
                PSON_LEN_TYPE = WORD;
        {$ENDIF}
        
        {$IFDEF PSON32}
                {$DEFINE _PSON_TYPE}
                PSON_LEN_TYPE = LONGINT;
        {$ENDIF}
{$ENDIF}

FUNCTION openDoc(item : PSON_PTR_TYPE) : PSON_PTR_TYPE;
FUNCTION docLength(item : PSON_PTR_TYPE) : PSON_LEN_TYPE;

FUNCTION getType(item : PSON_PTR_TYPE) : CHAR;
FUNCTION isType(item : PSON_PTR_TYPE; t : CHAR) : BOOLEAN;
PROCEDURE getKey(item : PSON_PTR_TYPE; VAR key : PSON_KEY_TYPE);
FUNCTION getValue(item : PSON_PTR_TYPE) : PSON_PTR_TYPE;

FUNCTION lookup(doc : PSON_PTR_TYPE; path : STRING) : PSON_PTR_TYPE;
FUNCTION next(p : PSON_PTR_TYPE) : PSON_PTR_TYPE;

FUNCTION asChar(value : PSON_PTR_TYPE) : PSON_CHAR_TYPE;
FUNCTION asInt(value : PSON_PTR_TYPE) : PSON_INT_TYPE;
FUNCTION asReal(value : PSON_PTR_TYPE) : PSON_REAL_TYPE;
FUNCTION asStr(value : PSON_PTR_TYPE) : PSON_STR_TYPE;

FUNCTION endDoc(item : PSON_PTR_TYPE; lastobj : PSON_PTR_TYPE) : PSON_PTR_TYPE;

FUNCTION addChar(doc : PSON_PTR_TYPE; key : PSON_KEY_TYPE; value : PSON_CHAR_TYPE) : PSON_PTR_TYPE;
FUNCTION addInt(doc : PSON_PTR_TYPE; key : PSON_KEY_TYPE; value : PSON_INT_TYPE) : PSON_PTR_TYPE;
FUNCTION addReal(doc : PSON_PTR_TYPE; key : PSON_KEY_TYPE; value : PSON_REAL_TYPE) : PSON_PTR_TYPE;
FUNCTION addStr(doc : PSON_PTR_TYPE; key : PSON_KEY_TYPE; value : PSON_STR_TYPE) : PSON_PTR_TYPE;
FUNCTION addObj(doc : PSON_PTR_TYPE; key : PSON_KEY_TYPE) : PSON_PTR_TYPE;

IMPLEMENTATION

CONST
LEN_SIZE = SizeOf(PSON_LEN_TYPE);
TYPE
LEN_PTR = ^PSON_LEN_TYPE;

FUNCTION next(p : PSON_PTR_TYPE) : PSON_PTR_TYPE;
VAR     t : CHAR;
BEGIN
        t := PSON_EOF;
        IF p <> NIL THEN t := p^;
        IF t <> PSON_EOF THEN BEGIN
                Inc(p);
                Inc(p, ORD(p^) + 1);
        END ELSE p := NIL;
        CASE t OF
        PSON_CHAR: Inc(p, SizeOf(PSON_CHAR_TYPE));
        PSON_INT:  Inc(p, SizeOf(PSON_INT_TYPE));
        PSON_REAL: Inc(p, SizeOf(PSON_REAL_TYPE));
        PSON_STR:  Inc(p, ORD(p^) + 1);
        PSON_OBJ:  Inc(p, LEN_PTR(p)^ + LEN_SIZE);
        ELSE p := NIL;
        END;
        IF p <> NIL THEN IF p^ = PSON_EOF THEN p := NIL;
        next := p;
END;

FUNCTION openDoc(item : PSON_PTR_TYPE) : PSON_PTR_TYPE;
BEGIN
        IF item <> NIL THEN openDoc := item + LEN_SIZE
        ELSE openDoc := NIL;
END;

FUNCTION getType(item : PSON_PTR_TYPE) : CHAR;
BEGIN
        getType := item^;
END;

FUNCTION isType(item : PSON_PTR_TYPE; t : CHAR) : BOOLEAN;
BEGIN
        isType := item^ = t;
END;

PROCEDURE getKey(item : PSON_PTR_TYPE; VAR key : PSON_KEY_TYPE);
BEGIN
        key := '';
        IF item <> NIL THEN BEGIN
                Inc(item);
                Move(item^, key, ORD(item^) + 1);
        END;
END;

FUNCTION getValue(item : PSON_PTR_TYPE) : PSON_PTR_TYPE;
BEGIN
        IF item <> NIL THEN BEGIN
                Inc(item);
                Inc(item, ORD(item^) + 1);
        END;
        getValue := item;
END;

FUNCTION lookup(doc : PSON_PTR_TYPE; path : STRING) : PSON_PTR_TYPE;
VAR     dpos : INTEGER;
        key  : STRING;
        ckey : STRING;
        r    : PSON_PTR_TYPE;
BEGIN
        r := NIL;
        dpos := Pos('\', path);
        IF dpos = 0 THEN BEGIN
                key := path;
                path := '';
        END ELSE BEGIN
                key := Copy(path, 1, dpos - 1);
                path := Copy(path, dpos + 1, length(path) - dpos);
        END;
        WHILE doc <> NIL DO BEGIN
                getKey(doc, ckey);
                IF key[0] = ckey[0] THEN IF key = ckey THEN BREAK;
                doc := next(doc);
        END;
        IF doc <> NIL THEN BEGIN
                IF Length(path) <> 0 THEN BEGIN
                        IF isType(doc, PSON_OBJ) THEN r := lookup(opendoc(getValue(doc)), path);
                END ELSE r := doc;
        END;
        lookup := r;
END;

FUNCTION asChar(value : PSON_PTR_TYPE) : PSON_CHAR_TYPE;
BEGIN
        IF value <> NIL THEN asChar := value^
        ELSE asChar := #0;
END;

FUNCTION asInt(value : PSON_PTR_TYPE) : PSON_INT_TYPE;
TYPE
PTR_TYPE = ^PSON_INT_TYPE;
BEGIN
        IF value <> NIL THEN asInt := PTR_TYPE(value)^
        ELSE asInt := 0;
END;

FUNCTION asReal(value : PSON_PTR_TYPE) : PSON_REAL_TYPE;
TYPE
PTR_TYPE = ^PSON_REAL_TYPE;
BEGIN
        IF value <> NIL THEN asReal := PTR_TYPE(value)^
        ELSE asReal := 0.0;
END;

FUNCTION asStr(value : PSON_PTR_TYPE) : PSON_STR_TYPE;
TYPE
PTR_TYPE = ^PSON_STR_TYPE;
BEGIN
        IF value <> NIL THEN asStr := PTR_TYPE(value)^
        ELSE asStr := '';
END;

FUNCTION newRec(doc : PSON_PTR_TYPE; t : CHAR; key  : PSON_KEY_TYPE) : PSON_PTR_TYPE;
VAR     len : INTEGER;
BEGIN
        doc^ := t;
        Inc(doc);
        len := Length(key) + 1;
        Move(key, doc^, len);
        Inc(doc, len);
        newRec := doc;
END;

FUNCTION addChar(doc : PSON_PTR_TYPE; key : PSON_KEY_TYPE; value : PSON_CHAR_TYPE) : PSON_PTR_TYPE;
BEGIN
        doc := newRec(doc, PSON_CHAR, key);
        doc^ := value;
        Inc(doc, SizeOf(value));
        addChar := doc;
END;

FUNCTION addInt(doc : PSON_PTR_TYPE; key : PSON_KEY_TYPE; value : PSON_INT_TYPE) : PSON_PTR_TYPE;
TYPE
PTR_TYPE = ^PSON_INT_TYPE;
BEGIN
        doc := newRec(doc, PSON_INT, key);
        PTR_TYPE(doc)^ := value;
        Inc(doc, SizeOf(value));
        addInt := doc;
END;

FUNCTION addReal(doc : PSON_PTR_TYPE; key : PSON_KEY_TYPE; value : PSON_REAL_TYPE) : PSON_PTR_TYPE;
TYPE
PTR_TYPE = ^PSON_REAL_TYPE;
BEGIN
        doc := newRec(doc, PSON_REAL, key);
        PTR_TYPE(doc)^ := value;
        Inc(doc, SizeOf(value));
        addReal := doc;
END;

FUNCTION addStr(doc : PSON_PTR_TYPE; key : PSON_KEY_TYPE; value : PSON_STR_TYPE) : PSON_PTR_TYPE;
VAR     len : INTEGER;
BEGIN
        len := ORD(value[0]) + 1;
        doc := newRec(doc, PSON_STR, key);
        Move(value, doc^, len);
        Inc(doc, len);
        addStr := doc;
END;

FUNCTION addObj(doc : PSON_PTR_TYPE; key : PSON_KEY_TYPE) : PSON_PTR_TYPE;
BEGIN
        addObj := newRec(doc, PSON_OBJ, key);
END;

FUNCTION endDoc(item : PSON_PTR_TYPE; lastobj : PSON_PTR_TYPE) : PSON_PTR_TYPE;
VAR     len : PSON_LEN_TYPE;
BEGIN
        lastobj^ := PSON_EOF;
        Inc(lastobj);
        len := lastobj - (item + LEN_SIZE);
        LEN_PTR(item)^ := len;
        endDoc := lastobj;
END;

FUNCTION docLength(item : PSON_PTR_TYPE) : PSON_LEN_TYPE;
BEGIN
        docLength := LEN_PTR(item)^ + LEN_SIZE;
END;

END.

