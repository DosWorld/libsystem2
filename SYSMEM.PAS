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
UNIT SysMem;

INTERFACE

CONST

EXTMEM_BLOCK_SIZE = 16 * 1024;

FUNCTION sysmem_avail : BOOLEAN;
FUNCTION sysmem_alloc(blk_count : WORD) : POINTER;
FUNCTION sysmem_put(h : POINTER; blk_num : WORD; VAR blk) : BOOLEAN;
FUNCTION sysmem_get(h : POINTER; blk_num : WORD; VAR blk) : BOOLEAN;
PROCEDURE sysmem_free(h : POINTER);

IMPLEMENTATION

USES SysEms, SysXms;

TYPE

DWORD = LONGINT;

TMEMTYPE    = (MT_NONE, MT_EMS, MT_XMS);

PSYSMEM_REC = ^TSYSMEM_REC;
TSYSMEM_REC = RECORD
        ems_h : WORD;
        xms_h : WORD;
        size  : WORD;
END;

VAR

ems_installed : BOOLEAN;
ems_window    : PCHAR;
ems_winnum    : WORD;
ems_windows   : ARRAY[0..3] OF WORD;
xms_installed : BOOLEAN;
memtype       : TMEMTYPE;

FUNCTION ems_alloc(VAR he : TSYSMEM_REC; blk_count : WORD) : BOOLEAN;
BEGIN
        he.ems_h := sysems.ems_malloc(blk_count);
        ems_alloc := he.ems_h <> 0;
END;

FUNCTION xms_alloc(VAR he : TSYSMEM_REC; blk_count : WORD) : BOOLEAN;
BEGIN
        he.xms_h := sysxms.xms_malloc(blk_count);
        xms_alloc := he.xms_h <> 0;
END;

FUNCTION ems_get_win(h : WORD) : WORD;
VAR     i : WORD;
BEGIN
        i := 0;
        WHILE i < 4 DO BEGIN
                IF ems_windows[i] = h THEN BEGIN
                        BREAK;
                END;
                Inc(i);
        END;
        IF i = 4 THEN BEGIN
                i := ems_winnum;
                ems_windows[i] := h;
                ems_winnum := (ems_winnum + 1) AND 3;
        END;
        ems_get_win := i;
END;

FUNCTION ems_get(VAR he : TSYSMEM_REC; blk_num : WORD; VAR blk) : BOOLEAN;
VAR     r : BOOLEAN;
        win : WORD;
BEGIN
        r := FALSE;
        win := ems_get_win(he.ems_h);
        IF sysems.ems_map(he.ems_h, blk_num, win) = EMS_STATUS_OK THEN BEGIN
                Move(ems_window[win SHL 14], blk, EMS_PAGE_SIZE);
                sysems.ems_map(he.ems_h, EMS_PAGE_UNMAP, win);
                r := TRUE;
        END;
        ems_get := r;
END;

FUNCTION xms_get(VAR he : TSYSMEM_REC; blk_num : WORD; VAR blk) : BOOLEAN;
BEGIN
        xms_copy(he.xms_h, blk_num, blk, XMS2DOS);
        xms_get := TRUE;
END;

FUNCTION ems_put(VAR he : TSYSMEM_REC; blk_num : WORD; VAR blk) : BOOLEAN;
VAR     r   : BOOLEAN;
        win : WORD;
BEGIN
        r := FALSE;
        win := ems_get_win(he.ems_h);
        IF sysems.ems_map(he.ems_h, blk_num, win) = EMS_STATUS_OK THEN BEGIN
                Move(blk, ems_window[win SHL 14], EMS_PAGE_SIZE);
                sysems.ems_map(he.ems_h, EMS_PAGE_UNMAP, win);
                r := TRUE;
        END;
        ems_put := r;
END;

FUNCTION xms_put(VAR he : TSYSMEM_REC; blk_num : WORD; VAR blk) : BOOLEAN;
BEGIN
        xms_copy(he.xms_h, blk_num, blk, DOS2XMS);
        xms_put := TRUE;
END;

PROCEDURE ems_free(VAR he : TSYSMEM_REC);
VAR     i : INTEGER;
BEGIN
        IF he.ems_h <> 0 THEN BEGIN
                FOR i := 0 TO 3 DO BEGIN
                        IF ems_windows[i] = he.ems_h THEN BEGIN
                                ems_windows[i] := 0;
                        END;
                END;
                sysems.ems_free(he.ems_h);
        END;
END;

PROCEDURE xms_free(VAR he : TSYSMEM_REC);
BEGIN
        IF he.xms_h <> 0 THEN sysxms.xms_free(he.xms_h);
END;

FUNCTION sysmem_avail : BOOLEAN;
BEGIN
        sysmem_avail := memtype IN [MT_EMS, MT_XMS];
END;

FUNCTION sysmem_alloc(blk_count : WORD):POINTER;
VAR     he : Psysmem_REC;
        r  : BOOLEAN;
BEGIN
        he := NIL;
        IF memtype <> MT_NONE THEN BEGIN
                GetMem(he, SizeOf(Tsysmem_REC));
                IF he <> NIL THEN BEGIN
                        FillChar(he^, SizeOf(Tsysmem_REC), #0);
                        IF memtype = MT_EMS THEN r := sysmem.ems_alloc(he^, blk_count)
                        ELSE IF memtype = MT_XMS THEN r := sysmem.xms_alloc(he^, blk_count)
                        ELSE r := FALSE;
                        IF r THEN he^.size := blk_count ELSE BEGIN
                                FreeMem(he, SizeOf(Tsysmem_REC));
                                he := NIL;
                        END;
                END;
        END;
        sysmem_alloc := he;
END;

FUNCTION sysmem_get(h : POINTER; blk_num:WORD; VAR blk) : BOOLEAN;
BEGIN
        IF h = NIL THEN sysmem_get := FALSE
        ELSE IF blk_num >= Psysmem_REC(h)^.size THEN sysmem_get := FALSE
        ELSE IF memtype = MT_XMS THEN sysmem_get := xms_get(PSYSMEM_REC(h)^, blk_num, blk)
        ELSE IF memtype = MT_EMS THEN sysmem_get := ems_get(PSYSMEM_REC(h)^, blk_num, blk)
        ELSE sysmem_get := FALSE;
END;

FUNCTION sysmem_put(h : POINTER; blk_num : WORD; VAR blk) : BOOLEAN;
BEGIN
        IF h = NIL THEN sysmem_put := FALSE
        ELSE IF blk_num >= Psysmem_REC(h)^.size THEN sysmem_put := FALSE
        ELSE IF memtype = MT_XMS THEN sysmem_put := xms_put(PSYSMEM_REC(h)^, blk_num, blk)
        ELSE IF memtype = MT_EMS THEN sysmem_put := ems_put(PSYSMEM_REC(h)^, blk_num, blk)
        ELSE sysmem_put := FALSE;
END;

PROCEDURE sysmem_free(h : POINTER);
BEGIN
        IF h = NIL THEN EXIT
        ELSE IF memtype = MT_XMS THEN xms_free(PSYSMEM_REC(h)^)
        ELSE IF memtype = MT_EMS THEN ems_free(PSYSMEM_REC(h)^);
        FreeMem(h, SizeOf(TSYSMEM_REC));
END;

BEGIN
        ems_installed := FALSE;
        xms_installed := FALSE;
        ems_window := NIL;
        FillChar(ems_windows, SizeOf(ems_windows), #0);
        memtype := MT_NONE;

        xms_installed := xms_check_driver;
        IF ems_check_driver THEN IF ems_get_status = EMS_STATUS_OK THEN BEGIN
                ems_installed := TRUE;
                ems_window := ems_get_window;
                ems_winnum := 0;
        END;

        IF xms_installed THEN memtype := MT_XMS
        ELSE IF ems_installed THEN memtype := MT_EMS;
END.
