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
UNIT UJSON;

INTERFACE

(*
----------------------------------------------------------------------
Example:

PROGRAM test;

USES ujson;

FUNCTION mycb(key, val : STRING; ctx : POINTER) : BOOLEAN;
BEGIN
	WriteLn(key, '=', val);
	mycb := TRUE;
END;

CONST
t : PCHAR =
'{' + #13 + #10 +
'  "pb": {' + #13 + #10 +
'    "p": 75,' + #13 + #10 +
'    "i": 0.5,' + #13 + #10 +
'    "d": 30,' + #13 + #10 +
'    "iMin": -50,' + #13 + #10 +
'    "iMax": 50' + #13 + #10 +
'  },' + #13 + #10 +
'  "pe": {' + #13 + #10 +
'    "p": 0.9,' + #13 + #10 +
'    "i": 0.001,' + #13 + #10 +
'    "d": 2.12,' + #13 + #10 +
'    "iMin": 0,' + #13 + #10 +
'    "iMax": 0' + #13 + #10 +
'  },' + #13 + #10 +
'  "p1": {' + #13 + #10 +
'    "p2": {' + #13 + #10 +
'        "p3": "12345",' + #13 + #10 +
'        p4: [ 1, 2, 3, 4, 5 ]' + #13 + #10 +
'    }' + #13 + #10 +
'  },' + #13 + #10 +
'  "bt": 24.5,' + #13 + #10 +
'  "et": 4.8,' + #13 + #10 +
'  "serial":"23A:001"' + #13 + #10 +
'}' + #13 + #10;

BEGIN
	WriteLn(ujson.Parse(t, @mycb, NIL));
	WriteLn(ujson.Parse(' [ 1, 2, 3, 4, 5, "Hello world!" ]'+#10, @mycb, NIL));
END.
----------------------------------------------------------------------
Must produce output: 

pb.p=75
pb.i=0.5
pb.d=30
pb.iMin=-50
pb.iMax=50
pe.p=0.9
pe.i=0.001
pe.d=2.12
pe.iMin=0
pe.iMax=0
p1.p2.p3=12345
p1.p2.p4.0=1
p1.p2.p4.1=2
p1.p2.p4.2=3
p1.p2.p4.3=4
p1.p2.p4.4=5
p1.p2.p4.size=5
bt=24.5
et=4.8
serial=23A:001
TRUE
0=1
1=2
2=3
3=4
4=5
5=Hello world!
size=6
TRUE
----------------------------------------------------------------------
*)

TYPE UJSON_CALL_BACK = FUNCTION(key, val : STRING; ctx : POINTER) : BOOLEAN;

FUNCTION Parse(p : PCHAR; cb : UJSON_CALL_BACK; ctx : POINTER) : BOOLEAN;

IMPLEMENTATION

CONST
OBJ_START = '{';
OBJ_END   = '}';
ARR_START = '[';
ARR_END   = ']';

FUNCTION SkipSpaces(VAR p : PCHAR) : CHAR; BEGIN WHILE (p^ <> #0) AND (p^ <= ' ') DO INC(p); SkipSpaces := p^; END;

FUNCTION IsChr(VAR p : PCHAR; c : CHAR) : BOOLEAN;
BEGIN
	IF p^ = c THEN BEGIN INC(p); IsChr := TRUE; END ELSE IsChr := FALSE;
END;

FUNCTION ParseSimpleValue(VAR p : PCHAR) : STRING;
VAR
	r : STRING;
	c : CHAR;
BEGIN
	r := '';
	IF IsChr(p, '"') THEN BEGIN
		WHILE NOT (p^ IN [#0, '"']) DO BEGIN
			IF IsChr(p, '\') THEN BEGIN
				c := p^;
				CASE c OF
				'0': c := #0;
				't': c := #9;
				'r': c := #13;
				'n': c := #10;
				END;
				r := r + c;
			END ELSE BEGIN
				r := r + p^;
			END;
			INC(p);
		END;
		IsChr(p, '"');
	END ELSE WHILE (p^ > ' ') AND (NOT (p^ IN [#0, ',', ARR_END, OBJ_END, ':'])) DO BEGIN
		r := r + p^;
		INC(p);
	END;
	SkipSpaces(p);
	ParseSimpleValue := r;
END;

FUNCTION ParseObject(VAR p : PCHAR; prefix : STRING; cb : UJSON_CALL_BACK; ctx : POINTER; endchr : CHAR) : BOOLEAN;
VAR ckey : STRING;
    cval : STRING;
	r    : BOOLEAN;
	i    : LONGINT;
BEGIN
	r := TRUE;
	i := 0;
	WHILE (NOT (SkipSpaces(p) IN [#0, OBJ_END, ARR_END])) AND r DO BEGIN
		IF endchr = ARR_END THEN BEGIN
			Str(i, ckey);
			INC(i);
		END ELSE BEGIN
			ckey := ParseSimpleValue(p);
			IF NOT IsChr(p, ':') THEN BEGIN r := FALSE; BREAK; END;
			SkipSpaces(p);
		END;
		IF IsChr(p, OBJ_START) THEN r := ParseObject(p, prefix + ckey + '.', cb, ctx, OBJ_END)
		ELSE IF IsChr(p, ARR_START) THEN r := ParseObject(p, prefix + ckey + '.', cb, ctx, ARR_END)
		ELSE BEGIN
			cval := ParseSimpleValue(p);
			r := cb(prefix + ckey, cval, ctx);
		END;
		IF NOT r THEN BREAK;
		IF NOT IsChr(p, ',') THEN BREAK;
	END;
	IF r THEN r := IsChr(p, endchr);
	IF r AND (endchr = ARR_END) THEN BEGIN
		Str(i, ckey);
		r := cb(prefix + 'size', ckey, ctx);
	END;
	SkipSpaces(p);
	ParseObject := r;
END;

FUNCTION Parse(p : PCHAR; cb : UJSON_CALL_BACK; ctx : POINTER) : BOOLEAN;
BEGIN
	SkipSpaces(p);
	IF IsChr(p, OBJ_START) THEN Parse := ParseObject(p, '', cb, ctx, OBJ_END)
	ELSE IF IsChr(p, ARR_START) THEN Parse := ParseObject(p, '', cb, ctx, ARR_END)
	ELSE Parse := FALSE;
END;

END.
