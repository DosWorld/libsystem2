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
{$A-,I-,S-,R-,D-,L-,Q-,F-,G-,O-,B-}
UNIT EXms;

INTERFACE

CONST
EXT_PAGE_SIZE  = $4000; { 16 kb }
EMS_STATUS_OK  = 0;

TYPE
MEM_COPY_DIRECTION = (DOS2EXT, EXT2DOS);

{ --- EMS -------------------------------------------------------- }

FUNCTION ems_check_driver : BOOLEAN;
FUNCTION ems_get_status : BYTE;
FUNCTION ems_maxavail : WORD;
FUNCTION ems_malloc(pages : WORD) : WORD;
FUNCTION ems_realloc(handle : WORD; old_page_count, new_page_count : WORD) : WORD;
PROCEDURE ems_copy(handle : WORD; page : WORD; VAR buf; dir : MEM_COPY_DIRECTION);
PROCEDURE ems_free(handle : WORD);

{ --- XMS -------------------------------------------------------- }

FUNCTION xms_check_driver : BOOLEAN;
FUNCTION xms_maxavail : WORD;
FUNCTION xms_malloc(pages : WORD) : WORD;
FUNCTION xms_realloc(handle : WORD; old_page_count, new_page_count : WORD) : WORD;
PROCEDURE xms_copy(handle : WORD; page : WORD; VAR buf; dir : MEM_COPY_DIRECTION);
PROCEDURE xms_free(handle : WORD);

{ --- EMS/XMS ---------------------------------------------------- }

FUNCTION exms_check_driver : BOOLEAN;
FUNCTION exms_maxavail : WORD;
FUNCTION exms_malloc(pages : WORD) : WORD;
FUNCTION exms_realloc(handle : WORD; old_page_count, new_page_count : WORD) : WORD;
PROCEDURE exms_copy(handle : WORD; page : WORD; VAR buf; dir : MEM_COPY_DIRECTION);
PROCEDURE exms_free(handle : WORD);

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

CONST
EMMDEVNAME    : STRING[8] = 'EMMXXXX0';

TYPE
DWORD = LONGINT;

TEMSCOPYREC = RECORD
        len      : DWORD;
        src_type : BYTE;
        src_hnd  : WORD;
        src_ofs  : WORD;
        src_seg  : WORD;
        dst_type : BYTE;
        dst_hnd  : WORD;
        dst_ofs  : WORD;
        dst_seg  : WORD;
END;

TXMSCOPYREC = RECORD
        len      : DWORD;
        src_hnd  : WORD;
        src_ofs  : DWORD;
        dst_hnd  : WORD;
        dst_ofs  : DWORD;
END;

CONST
EMS = 1;
XMS = 2;

VAR     emsrec     : TEMSCOPYREC;
        xmshandler : POINTER;
        xmsrec     : TXMSCOPYREC;
        mtype      : BYTE;

{ --- EMS -------------------------------------------------------- }

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

PROCEDURE ems_copy(handle : WORD; page : WORD; VAR buf; dir : MEM_COPY_DIRECTION);
BEGIN
        FillChar(emsrec, SizeOf(TEMSCOPYREC), #0);
        emsrec.len := EXT_PAGE_SIZE;
        IF dir = DOS2EXT THEN BEGIN
                emsrec.src_ofs := Ofs(buf);
                emsrec.src_seg := Seg(buf);
                emsrec.dst_type := 1;
                emsrec.dst_hnd := handle;
                emsrec.dst_seg := page;
        END ELSE IF dir = EXT2DOS THEN BEGIN
                emsrec.src_type := 1;
                emsrec.src_hnd := handle;
                emsrec.src_seg := page;
                emsrec.dst_ofs := Ofs(buf);
                emsrec.dst_seg := Seg(buf);
        END;
        ASM
                MOV  SI, offset emsrec
                MOV  AX, $5701
                INT  $67
        END;
END;

FUNCTION _ems_realloc(handle : WORD; new_page_count : WORD) : BOOLEAN;ASSEMBLER;
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
        IF _ems_realloc(handle, new_page_count) THEN h := handle
        ELSE BEGIN
                h := ems_malloc(new_page_count);
                IF h <> 0 THEN BEGIN
                        FillChar(emsrec, SizeOf(TEMSCOPYREC), #0);
                        emsrec.len := old_page_count * EXT_PAGE_SIZE;
                        emsrec.src_type := 1;
                        emsrec.src_hnd := handle;
                        emsrec.dst_type := 1;
                        emsrec.dst_hnd := h;
                        ASM
                                MOV  SI, offset emsrec
                                MOV  AX, $5701
                                INT  $67
                        END;
                        ems_free(handle);
                END;
        END;
        ems_realloc := h;
END;

{ --- XMS -------------------------------------------------------- }

FUNCTION xms_check_driver : BOOLEAN;ASSEMBLER;
ASM
        MOV  AX,$4300
        INT  $2F
        CMP  AL, $80
        JE   @ok
        XOR  AL, AL
@ok:
END;
                        
FUNCTION xms_get_handler : POINTER;ASSEMBLER;
ASM
        PUSH ES
        MOV  AX,$4310
        INT  $2F
        MOV  AX, BX
        MOV  DX, ES
        POP  ES
END;

FUNCTION xms_malloc(pages : WORD) : WORD;ASSEMBLER;
ASM
        MOV  AX, pages
        MOV  CL, 4
        SHL  AX, CL
        MOV  DX, AX
        MOV  AH, 9
        CALL [xmshandler]
        OR   AX, AX
        JNZ  @ok
        XOR  DX, DX
@ok:
        MOV  AX, DX
END;

PROCEDURE xms_free(handle : WORD);ASSEMBLER;
ASM
        MOV  DX, handle
        MOV  AH, $0A
        CALL [xmshandler]
END;

PROCEDURE xms_copy(handle : WORD; page : WORD; VAR buf; dir : MEM_COPY_DIRECTION);
VAR     buf_ptr : LONGINT;
        xms_ofs : LONGINT;
BEGIN
        FillChar(xmsrec, SizeOf(TXMSCOPYREC), #0);
        xmsrec.len := EXT_PAGE_SIZE;
        buf_ptr := LONGINT(@buf);
        xms_ofs := LONGINT(page) * EXT_PAGE_SIZE;
        IF dir = DOS2EXT THEN BEGIN
                xmsrec.src_hnd := 0;
                xmsrec.src_ofs := buf_ptr;
                xmsrec.dst_hnd := handle;
                xmsrec.dst_ofs := xms_ofs;
        END ELSE IF dir = EXT2DOS THEN BEGIN
                xmsrec.src_hnd := handle;
                xmsrec.src_ofs := xms_ofs;
                xmsrec.dst_hnd := 0;
                xmsrec.dst_ofs := buf_ptr;
        END;
        ASM
                MOV  SI, offset xmsrec
                MOV  AH, $0B
                CALL [xmshandler]
        END;
END;
        
FUNCTION _xms_realloc(handle : WORD; pcount : WORD) : BOOLEAN; ASSEMBLER;
ASM
        MOV  AX, pcount
        MOV  CL, 4
        SHL  AX, CL
        MOV  BX, AX
        MOV  DX, handle
        MOV  AH, $0F
        CALL [xmshandler]
END;

FUNCTION xms_realloc(handle : WORD; old_page_count, new_page_count : WORD) : WORD;
VAR     h : WORD;
BEGIN
        IF _xms_realloc(handle, new_page_count) THEN h := handle
        ELSE BEGIN
                h := xms_malloc(new_page_count);
                IF h <> 0 THEN BEGIN
                        FillChar(xmsrec, SizeOf(xmsrec), #0);
                        xmsrec.src_hnd := handle;
                        xmsrec.dst_hnd := h;
                        xmsrec.len := LONGINT(old_page_count) * EXT_PAGE_SIZE;
                        ASM
                                MOV  SI, offset xmsrec
                                MOV  AH, $0B
                                CALL [xmshandler]
                        END;
                        xms_free(handle);
                END;
        END;
        xms_realloc := h;
END;

FUNCTION xms_maxavail : WORD;ASSEMBLER;
ASM
        MOV  AH, 8
        CALL [xmshandler]
        MOV  CL, 4
        SHR  AX, CL
END;

FUNCTION exms_check_driver : BOOLEAN;
BEGIN
        exms_check_driver := mtype <> 0;
END;

FUNCTION exms_maxavail : WORD;
BEGIN
        IF mtype = EMS THEN exms_maxavail := ems_maxavail
        ELSE IF mtype = XMS THEN exms_maxavail := xms_maxavail
        ELSE exms_maxavail := 0;
END;

FUNCTION exms_malloc(pages : WORD) : WORD;
BEGIN
        IF mtype = EMS THEN exms_malloc := ems_malloc(pages)
        ELSE IF mtype = XMS THEN exms_malloc := xms_malloc(pages)
        ELSE exms_malloc := 0;
END;

FUNCTION exms_realloc(handle : WORD; old_page_count, new_page_count : WORD) : WORD;
BEGIN
        IF mtype = EMS THEN exms_realloc := ems_realloc(handle, old_page_count, new_page_count)
        ELSE IF mtype = XMS THEN exms_realloc := xms_realloc(handle, old_page_count, new_page_count)
        ELSE exms_realloc := 0;
END;

PROCEDURE exms_copy(handle : WORD; page : WORD; VAR buf; dir : MEM_COPY_DIRECTION);
BEGIN
        IF mtype = EMS THEN ems_copy(handle, page, buf, dir)
        ELSE IF mtype = XMS THEN xms_copy(handle, page, buf, dir);
END;

PROCEDURE exms_free(handle : WORD);
BEGIN
        IF mtype = EMS THEN ems_free(handle)
        ELSE IF mtype = XMS THEN xms_free(handle);
END;

PROCEDURE BAD_XMS_CALL;
BEGIN
        System.Writeln('Error in XMS call.');
        Halt(255);
END;

BEGIN
        mtype := 0;
        xmshandler := @BAD_XMS_CALL;
        IF xms_check_driver THEN BEGIN
                xmshandler := xms_get_handler;
                mtype := XMS;
        END ELSE IF ems_check_driver THEN mtype := EMS;
END.
