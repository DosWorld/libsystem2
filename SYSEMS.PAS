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
{$A+,I-,S-,R-,D-,L-,Q-,F-,G-,O-,B-}
UNIT SysEms;

INTERFACE

CONST

EMS_PAGE_SIZE  = 16*1024;
EMS_STATUS_OK  = 0;
EMS_PAGE_UNMAP = $FFFF;

FUNCTION ems_check_driver : BOOLEAN;
FUNCTION ems_get_status : BYTE;
FUNCTION ems_get_window : PCHAR;
FUNCTION ems_get_free_page_count : WORD;
FUNCTION ems_malloc(pages : WORD) : WORD;
PROCEDURE ems_free(handle : WORD);
{    dest : [0..3], page : [0..]   }
FUNCTION ems_map(handle : WORD; page : WORD; dest : BYTE) : BYTE;

IMPLEMENTATION

CONST

EMMDEVNAME    : STRING[8] = 'EMMXXXX0';

FUNCTION ems_get_status : BYTE;ASSEMBLER;
ASM
        MOV  AH, $40
        INT  $67
        MOV  AL, AH
END;

FUNCTION ems_get_window : PCHAR;ASSEMBLER;
ASM
        MOV  AH, $41
        INT  $67
        OR   AH, AH
        jz   @present
        XOR  BX, BX
@present:
        MOV  DX, BX
        XOR  AX, AX
END;

FUNCTION ems_get_free_page_count : WORD;ASSEMBLER;
ASM
        MOV  AH, $42
        INT  $67
        OR   AH, AH
        JZ   @present
        XOR  BX, BX
@present:
        MOV  AX, BX
END;

FUNCTION ems_malloc(pages : WORD) : WORD;ASSEMBLER;
ASM
        MOV  BX, pages
        MOV  AH, $43
        INT  $67
        OR   AH, AH
        JZ   @present
        XOR  DX, DX
@present:
        MOV  AX, DX
END;

PROCEDURE ems_free(handle : WORD);ASSEMBLER;
ASM
        MOV  AH, $45
        MOV  DX, handle
        INT  $67
END;

FUNCTION ems_map(handle : WORD; page : WORD; dest : BYTE) : BYTE; ASSEMBLER;
ASM
        MOV  AL, dest
        MOV  AH, $44
        MOV  BX, page
        MOV  DX, handle
        INT  $67
        MOV  AL, AH
END;

FUNCTION ems_check_driver : BOOLEAN;
VAR     dev_name : STRING[8];
        int67seg : WORD;
BEGIN
        ASM
                MOV  AX, $3567
                INT  $21
                MOV  AX, ES
                MOV  int67seg, AX
        END;
        Move(MEM[int67seg : $0A], dev_name[1], 8);
        dev_name[0] := #8;
        ems_check_driver := dev_name = EMMDEVNAME;
END;

END.
