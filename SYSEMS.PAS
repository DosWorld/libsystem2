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

TYPE
EMS_COPY_DIRECTION = (DOS2EMS, EMS2DOS);

FUNCTION ems_check_driver : BOOLEAN;
FUNCTION ems_get_status : BYTE;
FUNCTION ems_maxavail : WORD;
FUNCTION ems_malloc(pages : WORD) : WORD;
FUNCTION ems_realloc(handle : WORD; old_page_count, new_page_count : WORD) : WORD;
PROCEDURE ems_copy(handle : WORD; page : WORD; VAR buf; dir : EMS_COPY_DIRECTION);
PROCEDURE ems_free(handle : WORD);

IMPLEMENTATION

{$IFDEF DPMI}
This unit could be used only with real-mode DOS !
{$ENDIF}
{$IFDEF WINDOWS}
This unit could be used only with real-mode DOS !
{$ENDIF}
{$IFDEF LINUX}
This unit could be used only with real-mode DOS !
{$ENDIF}
{$IFDEF OS2}
This unit could be used only with real-mode DOS !
{$ENDIF}

CONST   EMMDEVNAME    : STRING[8] = 'EMMXXXX0';

TYPE
EMSCOPYREC = RECORD
        len      : LONGINT;
        src_type : BYTE;
        src_hnd  : WORD;
        src_ofs  : WORD;
        src_seg  : WORD;
        dst_type : BYTE;
        dst_hnd  : WORD;
        dst_ofs  : WORD;
        dst_seg  : WORD;
END;

VAR     copyrec : EMSCOPYREC;

FUNCTION ems_get_status : BYTE;ASSEMBLER;
ASM
        MOV  AH, $40
        INT  $67
        MOV  AL, AH
END;

FUNCTION ems_malloc(pages : WORD) : WORD;ASSEMBLER;
ASM
        MOV  BX, pages
        MOV  AH, $43
        INT  $67
        OR   AH, AH
        JZ   @ok
        XOR  DX, DX
@ok:
        MOV  AX, DX
END;

PROCEDURE ems_free(handle : WORD);ASSEMBLER;
ASM
        MOV  AH, $45
        MOV  DX, handle
        INT  $67
END;

FUNCTION ems_maxavail : WORD;ASSEMBLER;
ASM
        MOV  AH, $42
        INT  $67
        OR   AH, AH
        JZ   @ok
        XOR  BX, BX
@ok:
        MOV  AX, BX
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

PROCEDURE ems_copy(handle : WORD; page : WORD; VAR buf; dir : EMS_COPY_DIRECTION);
BEGIN
        FillChar(copyrec, SizeOf(copyrec), #0);
        copyrec.len := EMS_PAGE_SIZE;
        IF dir = DOS2EMS THEN BEGIN
                copyrec.src_ofs := Ofs(buf);
                copyrec.src_seg := Seg(buf);
                copyrec.dst_type := 1;
                copyrec.dst_hnd := handle;
                copyrec.src_seg := page;
                ASM
                        MOV  SI, offset copyrec
                        MOV  AX, $5701
                        INT  $67
                END;
        END ELSE IF dir = EMS2DOS THEN BEGIN
                copyrec.src_type := 1;
                copyrec.src_hnd := handle;
                copyrec.src_seg := page;
                copyrec.src_ofs := Ofs(buf);
                copyrec.src_seg := Seg(buf);
                ASM
                        MOV  SI, offset copyrec
                        MOV  AX, $5701
                        INT  $67
                END;
        END;
END;

FUNCTION _realloc(handle : WORD; new_page_count : WORD) : BOOLEAN;ASSEMBLER;
ASM
        MOV  BX, new_page_count
        MOV  DX, handle
        MOV  AH, $51
        INT  $67
        OR   AH, AH
        JZ   @ok
        MOV  AH, 1
@ok:
        MOV  AL, AH
        DEC  AL
END;

FUNCTION ems_realloc(handle : WORD; old_page_count, new_page_count : WORD) : WORD;
VAR     h : WORD;
BEGIN
        IF _realloc(handle, new_page_count) THEN h := handle
        ELSE BEGIN
                h := ems_malloc(new_page_count);
                IF h <> 0 THEN BEGIN
                        FillChar(copyrec, SizeOf(copyrec), #0);
                        copyrec.len := old_page_count * EMS_PAGE_SIZE;
                        copyrec.src_type := 1;
                        copyrec.src_hnd := handle;
                        copyrec.dst_type := 1;
                        copyrec.dst_hnd := h;
                        ASM
                                MOV  SI, offset copyrec
                                MOV  AX, $5701
                                INT  $67
                        END;
                        ems_free(handle);
                END;
        END;
        ems_realloc := h;
END;

END.