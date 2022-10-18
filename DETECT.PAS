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
UNIT Detect;

INTERFACE

CONST
CPU_86  = 0;
CPU_286 = 1;
CPU_386 = 2;

FUNCTION IsEga : BOOLEAN;
FUNCTION IsVga : BOOLEAN;
FUNCTION IsMonochrome : BOOLEAN;

FUNCTION IsInputRedirected : BOOLEAN;
FUNCTION IsOutputRedirected : BOOLEAN;
FUNCTION IsAnsiSys : BOOLEAN;

FUNCTION IsFreeDos : BOOLEAN;
FUNCTION GetFreeDosVer : PCHAR;

FUNCTION IsAT : BOOLEAN;
FUNCTION GetCpu : WORD;

IMPLEMENTATION

FUNCTION IsEga : BOOLEAN;ASSEMBLER;
ASM
        MOV  AX, $1200
        MOV  BX, $10
        MOV  CX, $FFFF
        INT  $10
        INC  CX
        MOV  AL, CL
        OR   AL, CH
END;

FUNCTION IsVga : BOOLEAN;ASSEMBLER;
ASM
        MOV  AX, $1A00
        INT  $10           {check for VGA/MCGA}
        CMP  AL, $1A
        JNE  @err          {no VGA Bios}
        CMP  BL, 7
        JB   @err          {is VGA or better?}
        CMP  BL, $FF
        JNE  @ok
@err:
        XOR  AL, AL
        JMP  @end
@ok:
        MOV  AL, 1
@end:
END;

FUNCTION IsFreeDos : BOOLEAN;ASSEMBLER;
ASM
        MOV  AX, $3000
        XOR  BX, BX
        INT  $21
        CMP  BH, $FD
        JE   @end
        XOR  BH, BH
@end:
        MOV  AL, BH
END;

FUNCTION GetFreeDosVer : PCHAR; ASSEMBLER;
ASM
        MOV  AX, $33FF
        XOR  DX, DX
        INT  $21
        TEST DX, DX
        JNZ  @end
        XOR  AX, AX
        MOV  DX, AX
@end:
END;

FUNCTION IsMonochrome : BOOLEAN;ASSEMBLER;
ASM
        PUSH DS
        MOV  AX, WORD PTR [seg0040]
        MOV  DS, AX
        MOV  AL, BYTE PTR [$0065]
        POP  DS
        AND  AL, 4
END;

FUNCTION IsInputRedirected : BOOLEAN; ASSEMBLER;
ASM
        MOV  AX, $4400
        XOR  BX, BX
        INT  $21
        XOR  AL, AL
        AND  DL, $81
        XOR  AL, AL
        OR   DL, DL
        JNZ  @end
        INC  AL
@end:
END;

FUNCTION IsOutputRedirected : BOOLEAN; ASSEMBLER;
ASM
        MOV  AX, $4400
        MOV  BX, 1
        INT  $21
        XOR  AL, AL
        AND  DL, $82
        XOR  AL, AL
        OR   DL, DL
        JNZ  @end
        INC  AL
@end:
END;

FUNCTION IsAnsiSys : BOOLEAN; ASSEMBLER;
ASM
        MOV     AX,$1A00
        INT     $2F
        XOR     AH, AH
END;

FUNCTION GetCpu : WORD; ASSEMBLER;
ASM
        XOR  DX, DX
        PUSH DX
        POPF
        PUSHF
        POP  AX
        AND  AX, $F000
        CMP  AX, $F000
        JE   @end
        INC  DX
        MOV  AX, $F000
        PUSH AX
        POPF
        PUSHF
        POP  AX
        AND  AX, $F000
        JZ   @end
        INC  DX
@end:
        MOV  AX, DX
END;

FUNCTION IsAT : BOOLEAN;
BEGIN
  IsAT := MEM[$F000 : $FFFE] = $FC;
END;

END.

