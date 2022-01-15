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
UNIT WinCB;
{ =========================================================================

  Windows Clipboard support for MS-DOS applications.

  ========================================================================= }

INTERFACE

FUNCTION WCB_Detect : BOOLEAN;

FUNCTION WCB_Copy(VAR d; size : WORD) : BOOLEAN;
FUNCTION WCB_Paste(VAR d; max_size : WORD) : BOOLEAN;

IMPLEMENTATION

FUNCTION WCB_Detect : BOOLEAN;ASSEMBLER;
ASM
        MOV  AX, $1700
        INT  $2F
        XOR  BX, BX
        CMP  AX, $1700
        JE   @end
        INC  BX
@end:
        MOV  AX, BX
END;

FUNCTION WCB_Clear : BOOLEAN;ASSEMBLER;
ASM
        MOV  AX, $1702
        INT  $2F
        XOR  BX, BX
        OR   AX, AX
        JZ   @end
        INC  BX
@end:
        MOV  AX, BX
END;

FUNCTION WCB_Open : BOOLEAN;ASSEMBLER;
ASM
        MOV  AX, $1701
        INT  $2F
        XOR  BX, BX
        OR   AX, AX
        JZ   @end
        INC  BX
@end:
        MOV  AX, BX
END;

PROCEDURE WCB_Close;ASSEMBLER;
ASM
        MOV  AX, $1708
        INT  $2F
END;

FUNCTION WCB_SetData(VAR d; size : WORD) : BOOLEAN;ASSEMBLER;
ASM
        PUSH ES
        LES  BX, d
        MOV  CX, size
        XOR  SI,SI
        MOV  AX, $1703
        MOV  DX, 1
        INT  $2F
        POP  ES
        XOR  BX, BX
        OR   AX, AX
        JZ   @end
        INC  BX
@end:
        MOV  BX, AX
END;

FUNCTION WCB_GetData(VAR d) : BOOLEAN;ASSEMBLER;
ASM
        PUSH ES
        LES  BX, d
        MOV  DX, 1
        MOV  AX, $1705
        INT  $2F
        POP  ES
        XOR  BX, BX
        OR   AX, AX
        JZ   @end
        INC  BX
@end:
        MOV  AX, BX
END;

FUNCTION WCB_GetDataSize : LONGINT;ASSEMBLER;
ASM
        MOV  AX, $1704
        MOV  DX, 1
        INT  $2F
END;

FUNCTION WCB_Copy(VAR d; size : WORD) : BOOLEAN;
VAR     r : BOOLEAN;
BEGIN
        r := FALSE;
        IF WCB_Detect THEN
                IF WCB_Open THEN
                        IF WCB_Clear THEN BEGIN
                                r := WCB_SetData(d, (size AND $FFE0) OR $1F);
                                WCB_Close;
                        END;
        WCB_Copy := r;
END;

FUNCTION WCB_Paste(VAR d; max_size : WORD) : BOOLEAN;
VAR     r    : BOOLEAN;
        size : LONGINT;
        p    : PCHAR;
BEGIN
        r := FALSE;
        IF WCB_Detect THEN
                IF WCB_Open THEN BEGIN
                        size := WCB_GetDataSize;
                        IF (size - 1) < max_size THEN BEGIN
                                r := WCB_GetData(d);
                                IF r THEN BEGIN
                                        p := @d;
                                        p[size] := #0;
                                END;
                        END;
                        WCB_Close;
                END;
        WCB_Paste := r;
END;

END.