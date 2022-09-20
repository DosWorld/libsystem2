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

TYPE
DWORD = LONGINT;

FUNCTION sysmem_avail : BOOLEAN;
FUNCTION sysmem_alloc : POINTER;
FUNCTION sysmem_put(p : POINTER; blk_num : DWORD; VAR blk) : BOOLEAN;
FUNCTION sysmem_get(p : POINTER; blk_num : DWORD; VAR blk) : BOOLEAN;
FUNCTION sysmem_truncate(p : POINTER; blk_num : DWORD) : BOOLEAN;
PROCEDURE sysmem_free(p : POINTER);

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

{USES SysEms, SysXms;}
USES EXms;

TYPE
TMEMTYPE = (MT_NONE, MT_EMS, MT_XMS);

TSYSMEMHNDL = RECORD
        hndl  : WORD;
        pages : WORD;
END;

PSYSMEM_REC = ^TSYSMEM_REC;
TSYSMEM_REC = RECORD
        size        : DWORD;
        hndls       : ARRAY[1..64] OF TSYSMEMHNDL; { 64MB * 64 = 4G }
        hndls_count : INTEGER;
END;

CONST
ems_installed : BOOLEAN = FALSE;
xms_installed : BOOLEAN = FALSE;
memtype       : TMEMTYPE = MT_NONE;

FUNCTION Realloc(VAR he : TSYSMEM_REC; blk_count : DWORD) : BOOLEAN;
VAR     nw, w, h, p     : WORD;
        maxavail        : WORD;
        i               : INTEGER;
        new_hndls_count : INTEGER;
BEGIN
        IF he.size = blk_count THEN EXIT;
        IF he.size > blk_count THEN BEGIN
                new_hndls_count := 0;
                he.size := 0;
                FOR i := 1 TO he.hndls_count DO BEGIN
                        h := he.hndls[i].hndl;
                        p := he.hndls[i].pages;
                        IF blk_count >= p THEN
                                Dec(blk_count, p)
                        ELSE IF blk_count = 0 THEN BEGIN
                                IF memtype = MT_XMS THEN xms_free(h)
                                ELSE IF memtype = MT_EMS THEN ems_free(h);
                                he.hndls[i].hndl := 0;
                                he.hndls[i].pages := 0;
                                p := 0;
                        END ELSE IF blk_count < p THEN BEGIN
                                IF memtype = MT_XMS THEN
                                        h := xms_realloc(h, p, blk_count)
                                ELSE IF memtype = MT_EMS THEN
                                        h := ems_realloc(h, p, blk_count);
                                IF h <> 0 THEN BEGIN
                                        he.hndls[i].hndl := h;
                                        he.hndls[i].pages := blk_count;
                                        new_hndls_count := i;
                                        p := blk_count;
                                        blk_count := 0;
                                END;
                        END;
                        Inc(he.size, p);
                END;
         END ELSE BEGIN
                Dec(blk_count, he.size);
                IF he.hndls_count <> 0 THEN BEGIN
                        w := 0;
                        h := he.hndls[he.hndls_count].hndl;
                        p := he.hndls[he.hndls_count].pages;
                        IF $0FF0 > p THEN w := $0FF0 - p;
                        IF w > blk_count THEN w := blk_count;
                        IF w <> 0 THEN BEGIN
                                nw := (w AND $FFFC) OR 3;
                                IF memtype = MT_XMS THEN
                                        h := xms_realloc(h, p, p + nw)
                                ELSE IF memtype = MT_EMS THEN
                                        h := ems_realloc(h, p, p + nw);
                                IF h <> 0 THEN BEGIN
                                        he.hndls[he.hndls_count].hndl := h;
                                        he.hndls[he.hndls_count].pages := p + w;
                                        Dec(blk_count, w);
                                        Inc(he.size, nw);
                                END;
                        END;
                END;
                WHILE blk_count <> 0 DO BEGIN
                        IF blk_count > $0FF0 THEN w := $0FF0 ELSE w := blk_count;
                        IF memtype = MT_XMS THEN maxavail := xms_maxavail
                        ELSE IF memtype = MT_EMS THEN maxavail := ems_maxavail;
                        IF maxavail = 0 THEN BREAK;
                        IF w > maxavail THEN BEGIN
                                w := maxavail;
                                Dec(blk_count, w);
                        END ELSE BEGIN
                                Dec(blk_count, w);
                                w := (w AND $FFFC) OR 3;
                        END;

                        IF memtype = MT_XMS THEN h := xms_malloc(w)
                        ELSE IF memtype = MT_EMS THEN h := ems_malloc(w);
                
                        IF h = 0 THEN BREAK;

                        Inc(he.hndls_count);
                        he.hndls[he.hndls_count].hndl := h;
                        he.hndls[he.hndls_count].pages := w;
                        Inc(he.size, w);
                END;
        END;
        Realloc := blk_count = 0;
END;

FUNCTION GetHandl(VAR he : TSYSMEM_REC; blk_num : DWORD; VAR new_blk_num : WORD) : WORD;
VAR     r, p : WORD;
        i    : INTEGER;
BEGIN
        r := 0;
        IF he.size > blk_num THEN BEGIN
                i := 1;
                WHILE i <= he.hndls_count DO BEGIN
                        p := he.hndls[i].pages;
                        IF p > blk_num THEN BEGIN
                                r := he.hndls[i].hndl;
                                new_blk_num := blk_num;
                                BREAK;
                        END;
                        Dec(blk_num, p);
                        Inc(i);
                END;
        END;
        GetHandl := r;
END;

FUNCTION sysmem_avail : BOOLEAN;
BEGIN
        sysmem_avail := memtype IN [MT_EMS, MT_XMS];
END;

FUNCTION sysmem_alloc : POINTER;
VAR     he : PSYSMEM_REC;
BEGIN
        he := NIL;
        IF memtype <> MT_NONE THEN BEGIN
                GetMem(he, SizeOf(TSYSMEM_REC));
                IF he <> NIL THEN FillChar(he^, SizeOf(TSYSMEM_REC), #0);
        END;
        sysmem_alloc := he;
END;

FUNCTION sysmem_get(p : POINTER; blk_num : DWORD; VAR blk) : BOOLEAN;
VAR     r    : BOOLEAN;
        h    : WORD;
        he   : PSYSMEM_REC;
        nnum : WORD;
BEGIN
        r := FALSE;
        IF p <> NIL THEN BEGIN
                he := PSYSMEM_REC(p);
                IF blk_num < he^.size THEN BEGIN
                        h := GetHandl(he^, blk_num, nnum);
                        IF h <> 0 THEN BEGIN
                                IF memtype = MT_XMS THEN xms_copy(h, nnum, blk, EXT2DOS)
                                ELSE IF memtype = MT_EMS THEN ems_copy(h, nnum, blk, EXT2DOS);
                                r := TRUE;
                        END;
                END;
        END;
        sysmem_get := r;
END;

FUNCTION sysmem_put(p : POINTER; blk_num : DWORD; VAR blk) : BOOLEAN;
VAR     r    : BOOLEAN;
        h    : WORD;
        he   : PSYSMEM_REC;
        nnum : WORD;
BEGIN
        r := FALSE;
        IF p <> NIL THEN BEGIN
                he := PSYSMEM_REC(p);
                IF blk_num < he^.size THEN h := GetHandl(he^, blk_num, nnum)
                ELSE IF Realloc(he^, blk_num + 1) THEN BEGIN
                        h := GetHandl(he^, blk_num, nnum);
                        he^.size := blk_num + 1;
                END;
                IF h <> 0 THEN BEGIN
                        IF memtype = MT_XMS THEN xms_copy(h, nnum, blk, DOS2EXT)
                        ELSE IF memtype = MT_EMS THEN ems_copy(h, nnum, blk, DOS2EXT);
                        r := TRUE;
                END;
        END;
        sysmem_put := r;
END;

PROCEDURE sysmem_free(p : POINTER);
VAR     i  : INTEGER;
        he : PSYSMEM_REC;
BEGIN
        IF p = NIL THEN EXIT;
        he := PSYSMEM_REC(p);
        FOR i := 1 TO he^.hndls_count DO BEGIN
                IF memtype = MT_XMS THEN BEGIN
                        xms_free(he^.hndls[i].hndl);
                END ELSE IF memtype = MT_EMS THEN BEGIN
                        ems_free(he^.hndls[i].hndl);
                END;
        END;
        FillChar(he^, SizeOf(TSYSMEM_REC), #0);
        FreeMem(p, SizeOf(TSYSMEM_REC));
END;

FUNCTION sysmem_truncate(p : POINTER; blk_num : DWORD) : BOOLEAN;
BEGIN
        IF p <> NIL THEN sysmem_truncate := Realloc(PSYSMEM_REC(p)^, blk_num + 1)
        ELSE sysmem_truncate := FALSE;
END;

BEGIN
        xms_installed := xms_check_driver;
        IF ems_check_driver THEN ems_installed := ems_get_status = EMS_STATUS_OK;
        IF xms_installed THEN memtype := MT_XMS
        ELSE IF ems_installed THEN memtype := MT_EMS;
END.
