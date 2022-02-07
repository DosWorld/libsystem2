UNIT Ansi;

INTERFACE

CONST
ANSI_ESC = CHR($1b);

BLACK    = 0;
RED      = 1;
GREEN    = 2;
YELLOW   = 3;
BLUE     = 4;
MAGENTA  = 5;
CYAN     = 6;
WHITE    = 7;

CLS      = ANSI_ESC + '[2J';
CLREOL   = ANSI_ESC + '[K';

CONST
ansi_enabled : BOOLEAN = TRUE;

FUNCTION AnsiSysInstalled : BOOLEAN;

FUNCTION fg(clr : BYTE) : STRING;
FUNCTION bg(clr : BYTE) : STRING;

IMPLEMENTATION

FUNCTION AnsiSysInstalled : BOOLEAN; ASSEMBLER;
ASM
        MOV     AX,$1A00
        INT     $2F
        XOR     AH, AH
END;

FUNCTION fg(clr : BYTE) : STRING;
BEGIN
        IF ansi_enabled THEN
                fg := ANSI_ESC + '[3' + CHR($30 + (clr mod 8)) + 'm'
        ELSE fg := '';
END;

FUNCTION bg(clr : BYTE) : STRING;
BEGIN
        IF ansi_enabled THEN
                bg := ANSI_ESC + '[4' + CHR($30 + (clr mod 8)) + 'm'
        ELSE bg := '';
END;

END.
