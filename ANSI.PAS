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
SOFTWARE. }
{$I switches.inc}
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

FUNCTION fg(clr : BYTE) : STRING;
FUNCTION bg(clr : BYTE) : STRING;

IMPLEMENTATION

USES Detect;

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

BEGIN
        ansi_enabled := IsAnsiSys AND (NOT IsOutputRedirected);
END.
