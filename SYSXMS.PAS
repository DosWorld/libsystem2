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
UNIT SysXms;

INTERFACE

CONST   XMS_PAGE_SIZE  = 16*1024;

TYPE
XMS_COPY_DIRECTION = (DOS2XMS, XMS2DOS);

FUNCTION xms_check_driver : BOOLEAN;
FUNCTION xms_maxavail : WORD;
FUNCTION xms_malloc(pages : WORD) : WORD;
FUNCTION xms_realloc(handle : WORD; old_page_count, new_page_count : WORD) : WORD;
PROCEDURE xms_copy(handle : WORD; page : WORD; VAR buf; dir : XMS_COPY_DIRECTION);
PROCEDURE xms_free(handle : WORD);

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

TYPE
XMSCOPYREC = RECORD
        len     : LONGINT;
        src_hnd : WORD;
        src_ofs : LONGINT;
        dst_hnd : WORD;
        dst_ofs : LONGINT;
END;

VAR     xmshandler : POINTER;
        copyrec    : XMSCOPYREC;

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

PROCEDURE xms_copy(handle : WORD; page : WORD; VAR buf; dir : XMS_COPY_DIRECTION);
VAR     buf_ptr : LONGINT;
        xms_ofs : LONGINT;
BEGIN
        copyrec.len := XMS_PAGE_SIZE;
        buf_ptr := LONGINT(@buf);
        xms_ofs := page * XMS_PAGE_SIZE;
        IF dir = DOS2XMS THEN BEGIN
                copyrec.src_hnd := 0;
                copyrec.src_ofs := buf_ptr;
                copyrec.dst_hnd := handle;
                copyrec.dst_ofs := xms_ofs;
                ASM
                        MOV  SI, offset copyrec
                        MOV  AH, $0B
                        CALL [xmshandler]
                END;
        END ELSE IF dir = XMS2DOS THEN BEGIN
                copyrec.src_hnd := handle;
                copyrec.src_ofs := xms_ofs;
                copyrec.dst_hnd := 0;
                copyrec.dst_ofs := buf_ptr;
                ASM
                        MOV  SI, offset copyrec
                        MOV  AH, $0B
                        CALL [xmshandler]
                END;
        END;
END;

FUNCTION _realloc(handle : WORD; pcount : WORD) : BOOLEAN; ASSEMBLER;
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
        IF _realloc(handle, new_page_count) THEN h := handle
        ELSE BEGIN
                h := xms_malloc(new_page_count);
                IF h <> 0 THEN BEGIN
                        FillChar(copyrec, SizeOf(copyrec), #0);
                        copyrec.src_hnd := handle;
                        copyrec.dst_hnd := h;
                        copyrec.len := old_page_count * XMS_PAGE_SIZE;
                        ASM
                                MOV  SI, offset copyrec
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

BEGIN
        IF xms_check_driver THEN xmshandler := xms_get_handler;
END.