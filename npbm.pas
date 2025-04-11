UNIT NPBM;

INTERFACE

FUNCTION LoadPBM(VAR f : FILE; VAR dest : PCHAR; VAR len, width, height : WORD) : BOOLEAN;

IMPLEMENTATION

PROCEDURE SkipToEol(VAR f: FILE);
VAR
	c : CHAR;
BEGIN
	c := #0;
	WHILE (NOT EOF(f)) AND (c <> #10) DO BlockRead(f, c, 1);
END;

FUNCTION ReadTextNumber(VAR f : FILE; VAR n : WORD) : BOOLEAN;
VAR
	ch : CHAR;
	s  : STRING;
	i  : INTEGER;
BEGIN
	WHILE NOT EOF(f) DO BEGIN
		BlockRead(f, ch, 1);
		IF (ch = '#') THEN SkipToEol(f)
		ELSE IF ch IN [' ', #9, #10, #13] THEN CONTINUE
		ELSE IF ch IN ['0'..'9'] THEN BEGIN
			s := ch;
			WHILE NOT EOF(f) DO BEGIN
				BlockRead(f, ch, 1);
				IF NOT (ch IN ['0'..'9']) THEN BEGIN Seek(f, FilePos(f) - 1); BREAK; END;
				INC(s[0]);
				s[ORD(s[0])] := ch;
			END;
			VAL(s, n, i);
			ReadTextNumber := i = 0;
			EXIT;
		END ELSE BREAK;
	END;
	ReadTextNumber := FALSE;
END;

FUNCTION LoadPBM(VAR f : FILE; VAR dest : PCHAR; VAR len, width, height : WORD) : BOOLEAN;
VAR
	ch1, ch2: CHAR;
	pitch, x, y, v: WORD;
	format, bitpos, byteval: BYTE;
	p: PCHAR;
BEGIN
	dest := NIL;
	len := 0;
	width := 0;
	height := 0;

	BlockRead(f, ch1, 1);
	BlockRead(f, ch2, 1);
	IF (ch1 <> 'P') OR NOT (ch2 IN ['1', '4']) THEN BEGIN LoadPBM := FALSE; EXIT; END;
	format := ORD(ch2) - ORD('0');

	IF NOT ReadTextNumber(f, width) THEN BEGIN LoadPBM := FALSE; EXIT; END;
	IF NOT ReadTextNumber(f, height) THEN BEGIN LoadPBM := FALSE; EXIT; END;

	SkipToEol(f);

	pitch := (width + 7) SHR 3;
	len := pitch * height;

	GetMem(dest, len);
	IF dest = NIL THEN BEGIN LoadPBM := FALSE; EXIT; END;

	p := dest;

	IF format = 1 THEN BEGIN
		FOR y := 0 TO height - 1 DO BEGIN
			byteval := 0;
			bitpos := 7;
			FOR x := 0 TO width - 1 DO BEGIN
				IF NOT ReadTextNumber(f, v) THEN BEGIN FreeMem(dest, len); LoadPBM := FALSE; EXIT; END;
				IF v = 1 THEN byteval := byteval OR (1 SHL bitpos);
				DEC(bitpos);
				IF bitpos = $FF THEN BEGIN
					p^ := CHR(byteval);
					INC(p);
					byteval := 0;
					bitpos := 7;
				END;
			END;
			IF bitpos <> 7 THEN BEGIN
				p^ := CHR(byteval);
				INC(p);
			END;
		END;
	END ELSE IF format = 4 THEN BlockRead(f, p^, len);

	LoadPBM := TRUE;
END;

END.