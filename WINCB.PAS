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

FUNCTION WCB_Detect:BOOLEAN;
PROCEDURE WCB_Open;
PROCEDURE WCB_Clear;
PROCEDURE WCB_GetData(VAR d);
PROCEDURE WCB_SetData(VAR d; size : WORD);
FUNCTION WCB_GetDataSize:LONGINT;
PROCEDURE WCB_Close;

IMPLEMENTATION

FUNCTION WCB_Detect:BOOLEAN;ASSEMBLER;
ASM
        MOV  AX, $1700
        INT  $2F
        XOR  BX, BX
        CMP  AX, $1700
        INT  $2F
        JE   @end
        INC  BX
@end:
        MOV  AX, BX
END;

PROCEDURE WCB_Clear;ASSEMBLER;
ASM
        MOV  AX, $1702
        INT  $2F
END;

PROCEDURE WCB_Open;ASSEMBLER;
ASM
        MOV  AX, $1701
        INT  $2F
END;

PROCEDURE WCB_Close;ASSEMBLER;
ASM
        MOV  AX, $1708
        INT  $2F
END;

PROCEDURE WCB_SetData(VAR d; size : WORD);ASSEMBLER;
ASM
        PUSH ES
        LES  BX, d
        MOV  CX, size
        XOR  SI,SI
        MOV  AX, $1703
        INT  $2F
        POP  ES
END;

PROCEDURE WCB_GetData(VAR d);ASSEMBLER;
ASM
        PUSH ES
        LES  BX, d
        MOV  DX, 1
        MOV  AX, $1705
        INT  $2F
        POP  ES
END;

FUNCTION WCB_GetDataSize:LONGINT;ASSEMBLER;
ASM
        MOV  AX, $1704
        MOV  DX, 1
        INT  $2F
END;

END.