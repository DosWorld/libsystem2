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
SOFTWARE.
}
{$A+,I-,S-,R-,D-,L-,Q-,F-,G-,O-,B-}
UNIT System2;
{ =========================================================================
  Hi !

  This units is designed to replace some functions from system unit.
  It has support for:

  1. Long file names
  2. Buffered I/O (DOS memory, 16K per file).
  3. Buffered I/O (EMS/XMS), up to 512 KB per file.
  4. File in memory (EMS/XMS) up to 4G each.
  5. Temporary files.
  6. Quoted command-line parameters.

  NOTE about 16K: This value became from EMS-page size,
  so please dont change it.

  ========================================================================= }
INTERFACE

{$DEFINE SYSMEM}
{$IFDEF DPMI}
{$UNDEF SYSMEM}
{$ENDIF}
{$IFDEF WINDOWS}
{$UNDEF SYSMEM}
{$ENDIF}

CONST CACHE_PAGES_PER_FILE = 32; { 512KB = 32*16K }

TYPE

TFILETYPE = (FS_FILE {$IFDEF SYSMEM}, MEM_FILE{$ENDIF} );
DWORD = LONGINT;
BFILE_BUF = ARRAY[0..16383] OF CHAR;

{$IFDEF SYSMEM}
TCACHE_PAGE = RECORD
        page       : WORD;
        notempty   : BOOLEAN;
        buf_update : BOOLEAN;
        buf_page   : DWORD;
        buf_count  : WORD;
END;
{$ENDIF}

PBFILE = ^BFILE;
BFILE = RECORD
        f           : WORD;
        filename    : STRING;
        filetype    : TFILETYPE;
        ioresult    : INTEGER;
        is_open     : BOOLEAN;
        buf         : ^BFILE_BUF;
        buf_page    : DWORD;
        buf_update  : BOOLEAN;
        buf_count   : WORD;
        buf_pos     : WORD;
        fsize       : DWORD;
{$IFDEF SYSMEM}
        has_cache   : BOOLEAN;
        cache_size  : WORD;
        cache_pages : ARRAY[0 .. CACHE_PAGES_PER_FILE-1] OF TCACHE_PAGE;
        sysmem_ptr  : POINTER;
{$ENDIF}
        delonclose  : BOOLEAN;
END;

PROCEDURE Assign (VAR f : BFILE; fname : STRING);
PROCEDURE Reset (VAR f : BFILE);
PROCEDURE ReWrite (VAR f : BFILE);
PROCEDURE Append (VAR f : BFILE);

{ ReWriteTemp does not requre call to Assign }
PROCEDURE ReWriteTemp (VAR f : BFILE);

{ ReWriteMemFile does not requre call to Assign.}
PROCEDURE ReWriteMemFile (VAR f : BFILE);

FUNCTION Eof (VAR f : BFILE) : BOOLEAN;
PROCEDURE Flush (VAR f : BFILE);

{ Set flag - delete file, when close }
PROCEDURE SetDeleteOnClose(VAR f : BFILE; flag : BOOLEAN);
PROCEDURE Close (VAR f : BFILE);
FUNCTION IsOpen(VAR f : BFILE):BOOLEAN;

FUNCTION ReadByte(VAR f : BFILE) : BYTE;
FUNCTION ReadWord(VAR f : BFILE) : WORD;
FUNCTION ReadDWord(VAR f : BFILE) : DWORD;
PROCEDURE ReadLn (VAR f : BFILE; VAR s : STRING);
FUNCTION BlockRead (VAR f : BFILE; VAR d; count : WORD) : WORD;

PROCEDURE WriteByte(VAR f : BFILE; b : BYTE);
PROCEDURE WriteWord(VAR f : BFILE; w : WORD);
PROCEDURE WriteDWord(VAR f : BFILE; dw : DWORD);
PROCEDURE Write (VAR f : BFILE; s : STRING);
PROCEDURE WriteLn (VAR f : BFILE; s : STRING);
PROCEDURE BlockWrite (VAR f : BFILE; VAR d; count : WORD);
FUNCTION BlockCopy (VAR src, dst : BFILE; count : DWORD) : DWORD;
PROCEDURE Seek (VAR f : BFILE; pos : DWORD);
FUNCTION FilePos (VAR f : BFILE) : DWORD;
PROCEDURE FilePosAlign (VAR f : BFILE; align : WORD);
FUNCTION FileSize (VAR f : BFILE) : DWORD;
PROCEDURE Truncate (VAR f : BFILE);
{ random access }
FUNCTION GetByte(VAR f : BFILE; ofs : DWORD) : BYTE;
FUNCTION GetWord(VAR f : BFILE; ofs : DWORD) : WORD;
FUNCTION GetDWord(VAR f : BFILE; ofs : DWORD) : DWORD;
PROCEDURE SetByte(VAR f : BFILE; ofs : DWORD; b : BYTE);
PROCEDURE SetWord(VAR f : BFILE; ofs : DWORD; w : WORD);
PROCEDURE SetDWord(VAR f : BFILE; ofs : DWORD; dw : DWORD);
PROCEDURE IncByte(VAR f : BFILE; ofs : DWORD; b : BYTE);
PROCEDURE IncWord(VAR f : BFILE; ofs : DWORD; w : WORD);
PROCEDURE IncDWord(VAR f : BFILE; ofs : DWORD; dw : DWORD);
PROCEDURE DecByte(VAR f : BFILE; ofs : DWORD; b : BYTE);
PROCEDURE DecWord(VAR f : BFILE; ofs : DWORD; w : WORD);
PROCEDURE DecDWord(VAR f : BFILE; ofs : DWORD; dw : DWORD);
{ }
PROCEDURE Erase (VAR f : BFILE);
PROCEDURE Rename (VAR f : BFILE; newName : STRING);
PROCEDURE GetDir(d : BYTE; VAR s : STRING);
PROCEDURE ChDir(s : STRING);
PROCEDURE MkDir(s : STRING);
PROCEDURE RmDir(s : STRING);

{ writes string to STDERR }
PROCEDURE WriteLnErr (s : STRING);

FUNCTION ParamCount : INTEGER;
FUNCTION ParamStr(i : INTEGER) : STRING;

{ Set default cache size in 16k pages, for new open file calls }
PROCEDURE SetDefaultCacheSize(i : INTEGER);

{ Enable/disable using temp files, if cant create in-memory file}
PROCEDURE SetUseTempFiles(status : BOOLEAN);

FUNCTION FileExists(s : STRING):BOOLEAN;
PROCEDURE FileDelete(s : STRING);

FUNCTION GetCurrentDisk : BYTE;
PROCEDURE SetCurrentDisk(disk : BYTE);

FUNCTION IsFreeDos : BOOLEAN;
FUNCTION GetFreeDosVer : PCHAR;

IMPLEMENTATION

USES {$IFDEF SYSMEM}SysMem, QSort,{$ENDIF}Dos;

CONST

STDIN  = 0;
STDOUT = 1;
STDERR = 2;

SEEK_BEG = 0;
SEEK_CUR = 1;
SEEK_END = 2;

LN_STR : STRING[2] = #$0D + #$0A;
use_temp : BOOLEAN = FALSE;
SELFNAME : PCHAR = NIL;

TYPE

PSTRING = ^STRING;
PWORD   = ^WORD;

{$IFDEF SYSMEM}
SORT_PAGE = RECORD
        old        : WORD;
        buf_page   : DWORD;
END;
PSORT_PAGE_INFO = ^SORT_PAGE_INFO;
SORT_PAGE_INFO = ARRAY[0 .. CACHE_PAGES_PER_FILE-1] OF SORT_PAGE;
{$ENDIF}

VAR     fname              : STRING;
        fname2             : STRING;
        res                : WORD;
        prevExitProc       : POINTER;
{$IFDEF SYSMEM}
        default_cache_size : WORD;
{$ENDIF}
FUNCTION IsOpen(VAR f : BFILE):BOOLEAN;
BEGIN
        IsOpen := f.is_open;
END;

FUNCTION lReWrite : WORD;ASSEMBLER;
ASM
        PUSH DS
        MOV  SI, offset fname + 1
        MOV  BX, $22
        XOR  CX, CX
        MOV  RES, CX
        MOV  DX, $12
        MOV  AX, seg fname
        MOV  DS, AX
        XOR  DI, DI
        STC
        MOV  AX, $716C
        INT  $21
        JNC  @end

        MOV  DX, offset fname + 1
        MOV  AX, seg fname
        MOV  DS, AX
        MOV  AH, $3C
        XOR  CX, CX
        INT  $21
        JNC  @end
        MOV  RES, AX
        XOR  AX, AX
@end:
        POP  DS
END;

FUNCTION lReset:WORD;ASSEMBLER;
ASM
        PUSH DS
        XOR  AX, AX
        MOV  RES, AX
        MOV  SI, offset fname + 1
        MOV  BX, $22 { access attr}
        XOR  CX, CX
        MOV  DX, $1
        MOV  AX, seg fname
        MOV  DS, AX
        XOR  DI, DI
        STC
        MOV  AX, $716C
        INT  $21
        JNC  @end

        MOV  DX, offset fname + 1
        MOV  AX, seg fname
        MOV  DS, AX
        MOV  AX, $3D02
        INT  $21
        JNC  @end

        MOV  RES, AX
        XOR  AX, AX
@end:
        POP  DS
END;

FUNCTION lRead(h : WORD; VAR dest; count : WORD) : WORD;ASSEMBLER;
ASM
        PUSH DS
        XOR  AX, AX
        MOV  RES, AX
        MOV  BX, h
        MOV  CX, count
        LDS  DX, dest
        MOV  AH, $3F
        INT  $21
        POP  DS
        JNC  @ok
        MOV  RES, AX
        XOR  AX, AX
@ok:
END;

FUNCTION lWrite(h : WORD; VAR dest; count : WORD) : WORD;ASSEMBLER;
ASM
        PUSH DS
        XOR  AX, AX
        MOV  RES, AX
        MOV  BX, h
        MOV  CX, count
        LDS  DX, dest
        MOV  AH, $40
        INT  $21
        POP  DS
        JNC  @ok
        MOV  RES, AX
        XOR  AX, AX
@ok:
END;

PROCEDURE lTruncate(h : WORD);ASSEMBLER;
ASM
        MOV  BX, h
        XOR  CX, CX
        MOV  AH, $40
        INT  $21
END;

PROCEDURE lSeek(h : WORD; seek_typ : BYTE; pos : DWORD);ASSEMBLER;
ASM
        MOV  BX, h
        MOV  DX, word ptr [pos]
        MOV  CX, word ptr [pos + 2]
        MOV  AH, $42
        MOV  AL, seek_typ
        INT  $21
END;

FUNCTION lTell(h : word) : DWORD;ASSEMBLER;
ASM
        MOV  BX, h
        XOR  DX, DX
        MOV  CX, DX
        MOV  AX, $4201
        INT  $21
END;

PROCEDURE lClose(h : WORD);ASSEMBLER;
ASM
        MOV  BX, h
        MOV  AH, $3E
        INT  $21
END;

PROCEDURE lErase;ASSEMBLER;
ASM
        XOR  AX, AX
        MOV  RES, AX
        PUSH DS
        MOV  DI, offset fname + 1
        XOR  CX, CX
        MOV  AX, seg fname
        MOV  DS, AX
        XOR  SI, SI
        STC
        MOV  AX, $7141
        INT  $21
        MOV  AL, 1
        JC   @cont
        DEC  AL
@cont:
        OR   AL, AL
        JZ   @end
        XOR  CX, CX
        MOV  DX, offset fname + 1
        MOV  AX, seg fname
        MOV  DS, AX
        STC
        MOV  AH, $41
        INT  $21
        MOV  AL, 1
        JC   @end
        DEC  AL
@end:
        POP  DS
        XOR  AH, AH
        MOV  RES, AX
END;

PROCEDURE ChDir(s : STRING);
BEGIN
        fname := s + #0;
        ASM
                PUSH DS
                MOV  AX, seg fname
                MOV  DS, AX
                MOV  DX, offset fname + 1
                MOV  AX, $713B
                PUSH DS
                PUSH DX
                STC
                INT  $21
                POP  DX
                POP  DS
                JNC  @end
                MOV  AH, $3b
                INT  $21
        @end:
                POP  DS
        END;
END;

PROCEDURE MkDir(s : STRING);
BEGIN
        fname := s + #0;
        ASM
                PUSH DS
                MOV  AX, seg fname
                MOV  DS, AX
                MOV  DX, offset fname + 1
                MOV  AX, $7139
                PUSH DS
                PUSH DX
                STC
                INT  $21
                POP  DX
                POP  DS
                JNC  @end
                MOV  AH, $39
                INT  $21
        @end:
                POP  DS
        END;
END;

PROCEDURE RmDir(s : STRING);
BEGIN
        fname := s + #0;
        ASM
                PUSH DS
                MOV  AX, seg fname
                MOV  DS, AX
                MOV  DX, offset fname + 1
                MOV  AX, $713A
                PUSH DS
                PUSH DX
                STC
                INT  $21
                POP  DX
                POP  DS
                JNC  @end
                MOV  AH, $3A
                INT  $21
        @end:
                POP  DS
        END;
END;

FUNCTION lRename:BOOLEAN;ASSEMBLER;
ASM
        PUSH DS
        MOV  AX, seg fname
        MOV  DS, AX
        MOV  ES, AX
        MOV  DX, offset fname + 1
        MOV  DI, offset fname2 + 1
        STC
        MOV  AX, $7156
        INT  $21
        MOV  AX, 1
        JNC  @ok
        
        MOV  AX, seg fname
        MOV  DS, AX
        MOV  ES, AX
        MOV  DX, offset fname + 1
        MOV  DI, offset fname2 + 1
        MOV  AH, $56
        STC
        INT  $21
        MOV  AX, 1
        JNC  @ok
        XOR  AX, AX
@ok:
        POP  DS
END;

PROCEDURE Rename(VAR f : BFILE; newName : STRING);
BEGIN
        f.ioresult := 0;
        IF f.is_open THEN EXIT;
        fname := f.filename + #0;
        fname2 := newName + #0;
        IF lRename THEN f.filename := newName ELSE f.ioresult := 5;
END;

PROCEDURE GetDir(d : BYTE; VAR s : STRING);
VAR
        res : INTEGER;
BEGIN
        res := 0;
        s[0] := #0;
        ASM
                PUSH DS
                LDS  SI, s
                INC  SI
                MOV  AX, $7147
                STC
                MOV  DL, d
                PUSH DX
                PUSH DS
                PUSH SI
                INT  $21
                POP  SI
                POP  DS
                POP  DX
                MOV  AX, 1
                JNC  @end

                MOV  AH, $47
                STC
                INT  $21
                MOV  AX, 1
                JNC  @end
                XOR  AX, AX
        @end:
                POP  DS
                MOV  res, AX
        END;
        IF res <> 0 THEN BEGIN
                WHILE s[0] <> #255 DO BEGIN
                        IF s[ORD(s[0])+1] = #0 THEN BREAK;
                        Inc(s[0]);
                END;
        END;
END;

FUNCTION ParamCount : INTEGER;
VAR     r, len : INTEGER;
        str    : PSTRING;
        pos    : INTEGER;
BEGIN
        r := 0;
        str := PString(ptr(PrefixSeg, $80));
        pos := 1;
        len := ORD(str^[0]);
        WHILE pos <= ORD(str^[0]) DO BEGIN
                WHILE (str^[pos] <= ' ') AND (pos <= len) DO Inc(pos);
                IF pos > len THEN BREAK;
                IF str^[pos] = '"' THEN BEGIN
                        Inc(pos);
                        WHILE (str^[pos] <> '"') AND (pos <= len) DO BEGIN
                                Inc(pos);
                        END;
                        Inc(pos);
                        Inc(r);
                END ELSE BEGIN
                        WHILE (str^[pos] > ' ') AND (pos <= len) DO BEGIN
                                Inc(pos);
                        END;
                        Inc(r);
                END;
        END;
        ParamCount := r;
END;

FUNCTION ParamStr(i : INTEGER) : STRING;
VAR     r   : STRING;
        str : PSTRING;
        pos : INTEGER;
        len : INTEGER;
        c   : CHAR;
        p   : PCHAR;
BEGIN
        r[0] := #0;
        IF i <> 0 THEN BEGIN
                str := PString(ptr(PrefixSeg, $80));
                len := ORD(str^[0]);
                pos := 1;
                Dec(i);
                WHILE pos <= len DO BEGIN
                        WHILE (str^[pos] <= ' ') AND (pos <= len) DO Inc(pos);
                        IF pos > len THEN BREAK;
                        IF str^[pos] = '"' THEN BEGIN
                                Inc(pos);
                                WHILE (str^[pos] <> '"') AND (pos <= len) DO BEGIN
                                        IF i = 0 THEN BEGIN
                                                Inc(r[0]);
                                                r[ORD(r[0])] := str^[pos];
                                        END;
                                        Inc(pos);
                                END;
                                Inc(pos);
                                Dec(i);
                        END ELSE BEGIN
                                WHILE (str^[pos] > ' ') AND (pos <= len) DO BEGIN
                                        IF i = 0 THEN BEGIN
                                                Inc(r[0]);
                                                r[ORD(r[0])] := str^[pos];
                                        END;
                                        Inc(pos);
                                END;
                                Dec(i);
                        END;
                END;
        END ELSE BEGIN
                IF SELFNAME = NIL THEN BEGIN
                        SELFNAME := ptr(PWORD(ptr(PrefixSeg, $2C))^, 0);
                        c := #0;
                        WHILE NOT ((SELFNAME[0] = #0) AND (c = #0)) DO BEGIN
                                c := SELFNAME[0];
                                Inc(SELFNAME, 1);
                        END;
                        Inc(SELFNAME, 3);
                END;
                IF SELFNAME <> NIL THEN BEGIN
                        p := SELFNAME;
                        WHILE r[0] <> #255 DO BEGIN
                                IF p[0] = #0 THEN BREAK;
                                Inc(r[0]);
                                r[ORD(r[0])] := p[0];
                                Inc(p);
                        END;
                END;
        END;
        ParamStr := r;
END;

{$IFDEF SYSMEM}
PROCEDURE InitCache(VAR f : BFILE);
VAR     i : INTEGER;
BEGIN
        f.sysmem_ptr := NIL;
        f.cache_size := default_cache_size;
        f.has_cache := FALSE;
        FillChar(f.cache_pages, SizeOf(f.cache_pages), #0);
        IF (NOT f.is_open) OR (f.cache_size = 0) THEN EXIT;
        f.sysmem_ptr := sysmem_alloc;
        f.has_cache := f.sysmem_ptr <> NIL;
        IF f.has_cache THEN BEGIN
                i := 0;
                WHILE i < f.cache_size DO BEGIN
                        f.cache_pages[i].page := i;
                        Inc(i);
                END;
        END;
END;
{$ENDIF}

PROCEDURE Assign(VAR f : BFILE; fname : STRING);
BEGIN
        FillChar(f, SizeOf(BFILE), #0);
        f.filename := fname;
        f.filetype := FS_FILE;
END;

PROCEDURE ReWrite(VAR f : BFILE);
BEGIN
        IF f.is_open THEN EXIT;
        GetMem(f.buf, SizeOf(BFILE_BUF));
        IF f.buf = NIL THEN EXIT;
        fname := f.filename + #0;
        f.ioresult := 0;
        f.f := lReWrite;
        IF f.f = 0 THEN f.ioresult := 5;
        f.is_open := f.ioresult = 0;
        f.buf_count := 0;
        f.buf_pos := 0;
        f.buf_page := 0;
        f.buf_update := FALSE;
        f.fsize := 0;
        f.delonclose := FALSE;
        f.filetype := FS_FILE;
{$IFDEF SYSMEM}
        InitCache(f);
{$ENDIF}
        IF NOT f.is_open THEN BEGIN FreeMem(f.buf, SizeOf(BFILE_BUF)); f.buf := NIL; END;
END;

PROCEDURE Reset(VAR f : BFILE);
BEGIN
        IF f.is_open THEN EXIT;
        GetMem(f.buf, SizeOf(BFILE_BUF));
        IF f.buf = NIL THEN EXIT;
        f.ioresult := 0;
        fname := f.filename + #0;
        f.f := lReset;
        IF f.f = 0 THEN f.ioresult := 2;
        f.is_open := f.ioresult = 0;
        f.buf_count := 0;
        f.buf_pos := 0;
        f.buf_page := 0;
        f.buf_update := FALSE;
        f.delonclose := FALSE;
{$IFDEF SYSMEM}
        f.cache_size := 0;
        f.sysmem_ptr := NIL;
{$ENDIF}
        f.filetype := FS_FILE;
        IF f.is_open THEN BEGIN
                lSeek(f.f, SEEK_END, 0);
                f.fsize := lTell(f.f);
                lSeek(f.f, SEEK_BEG, 0);
                f.buf_count := lRead(f.f, f.buf^[0], SizeOf(BFILE_BUF));
                if res <> 0 THEN f.ioresult := 100;
{$IFDEF SYSMEM}
                InitCache(f);
{$ENDIF}
        END;
        IF NOT f.is_open THEN BEGIN FreeMem(f.buf, SizeOf(BFILE_BUF)); f.buf := NIL; END;
END;

PROCEDURE Append (VAR f : BFILE);
BEGIN
        Reset(f);
        IF f.is_open THEN Seek(f, FileSize(f)) ELSE ReWrite(f);
END;

PROCEDURE ReWriteTemp(VAR f : BFILE);
CONST
CHARS : string = '0123456789-_QWERTYUIOPASDFGHJKLZXCVBNM';
VAR     tmp  : STRING;
        name : STRING[12];
        i    : INTEGER;
BEGIN
        FillChar(f, SizeOf(BFILE), #0);
        tmp := GetEnv('TMP');
        IF Length(tmp) = 0 THEN tmp := GetEnv('TEMP');
        IF Length(tmp) = 0 THEN tmp := GetEnv('HOME');
        IF Length(tmp) = 0 THEN GetDir(0, tmp);
        IF Length(tmp) <> 0 THEN BEGIN
                IF NOT (tmp[ORD(tmp[0])] IN ['\', '/']) THEN tmp := tmp + '\';
        END;
        FOR i := 1 TO 8 DO name[i] := CHARS[1 + Random(ORD(CHARS[0]))];
        name[0] := #8;
        name := name + '.TMP';
        Assign(f, tmp + name);
        ReWrite(f);
        Truncate(f);
        SetDeleteOnClose(f, TRUE);
END;

PROCEDURE ReWriteMemFile(VAR f : BFILE);
{$IFDEF SYSMEM}
VAR     s             : STRING;
BEGIN
        FillChar(f, SizeOf(BFILE), #0);
        IF use_temp THEN BEGIN ReWriteTemp(f); EXIT; END;
        GetMem(f.buf, SizeOf(BFILE_BUF));
        IF f.buf = NIL THEN EXIT;
        f.sysmem_ptr := sysmem_alloc;
        f.is_open := f.sysmem_ptr <> NIL;
        f.has_cache := f.sysmem_ptr <> NIL;
        IF f.is_open THEN BEGIN
                str(LONGINT(f.sysmem_ptr), s);
                f.filetype := MEM_FILE;
                f.filename := 'MEM:FILE' + s + '.TMP';
        END ELSE BEGIN
                FreeMem(f.buf, SizeOf(BFILE_BUF)); f.buf := NIL;
                ReWriteTemp(f);
        END;
END;
{$ENDIF}
{$IFNDEF SYSMEM}
BEGIN
        ReWriteTemp(f);
END;
{$ENDIF}

PROCEDURE UpdateFileSize(VAR f : BFILE);
VAR     ns : DWORD;
BEGIN
        ns := f.buf_page * SizeOf(BFILE_BUF) + f.buf_count;
        IF f.fsize < ns THEN f.fsize := ns;
END;

FUNCTION Eof(VAR f : BFILE) : BOOLEAN;
BEGIN
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 103;
                EXIT;
        END;
        f.ioresult := 0;
        UpdateFileSize(f);
        Eof := (f.buf_page * SizeOf(BFILE_BUF) + f.buf_pos) = f.fsize;
END;

{$IFDEF SYSMEM}
PROCEDURE MakeCachedPageTop(VAR f : BFILE; pgnum : WORD);
VAR     tmp : TCACHE_PAGE;
        i   : WORD;
BEGIN
        IF pgnum = 0 THEN EXIT;
        tmp := f.cache_pages[pgnum];
        i := pgnum;
        WHILE i <> 0 DO BEGIN
                f.cache_pages[i] := f.cache_pages[i - 1];
                Dec(i);
        END;
        f.cache_pages[0] := tmp;
END;

PROCEDURE StorePageToSysMem(VAR f : BFILE; i : INTEGER);
BEGIN
        IF f.cache_pages[i].buf_update THEN Flush(f);

        sysmem_put(f.sysmem_ptr, f.cache_pages[i].page, f.buf^[0]);
        f.cache_pages[i].buf_count := f.buf_count;
        f.cache_pages[i].buf_page := f.buf_page;
        f.cache_pages[i].buf_update := f.buf_update;
        f.cache_pages[i].notempty := TRUE;
        f.buf_update := FALSE;
        MakeCachedPageTop(f, i);
END;

PROCEDURE PushPageToCache(VAR f : BFILE);
VAR     i     : INTEGER;
        fpage : INTEGER;
        count : INTEGER;
BEGIN
        i := 0;
        fpage := -1;
        WHILE i < f.cache_size DO BEGIN
                IF f.cache_pages[i].notempty THEN BEGIN
                        IF f.cache_pages[i].buf_page = f.buf_page THEN BEGIN
                                StorePageToSysMem(f, i);
                                f.buf_update := FALSE;
                                EXIT;
                        END;
                END ELSE IF fpage = -1 THEN fpage := i;
                Inc(i);
        END;
        IF fpage <> -1 THEN BEGIN
                StorePageToSysMem(f, fpage);
        END ELSE BEGIN
                StorePageToSysMem(f, f.cache_size - 1);
        END;
END;

FUNCTION GetPageFromCache(VAR f : BFILE):BOOLEAN;
VAR     r    : BOOLEAN;
        i    : INTEGER;
BEGIN
        r := FALSE;
        i := 0;
        WHILE (i < f.cache_size) AND (NOT r) DO BEGIN
                IF f.cache_pages[i].notempty AND (f.cache_pages[i].buf_page = f.buf_page) THEN BEGIN
                        MakeCachedPageTop(f, i);
                        sysmem_get(f.sysmem_ptr, f.cache_pages[0].page, f.buf^[0]);
                        f.buf_count := f.cache_pages[0].buf_count;
                        f.buf_update := f.cache_pages[0].buf_update;
                        f.buf_pos := 0;
                        f.cache_pages[0].buf_update := FALSE;
                        r := TRUE;
                        BREAK;
                END;
                Inc(i);
        END;
        GetPageFromCache := r;
END;

PROCEDURE MemFileSwitchPage(VAR f : BFILE; new_page : DWORD);
VAR     ns        : DWORD;
BEGIN
        IF f.buf_update THEN BEGIN
                ns := f.buf_page * SizeOf(BFILE_BUF) + f.buf_count;
                IF f.fsize < ns THEN f.fsize := ns;
                sysmem_put(f.sysmem_ptr, f.buf_page, f.buf^[0]);
                f.buf_update := FALSE;
        END;
        f.buf_page := new_page;
        f.buf_pos := 0;
        sysmem_get(f.sysmem_ptr, f.buf_page, f.buf^[0]);
END;
{$ENDIF}

PROCEDURE FsSwitchPage(VAR f : BFILE; new_page : DWORD);
VAR     ns        : DWORD;
BEGIN
        IF f.buf_update THEN BEGIN
                ns := f.buf_page * SizeOf(BFILE_BUF) + f.buf_count;
                IF f.fsize < ns THEN f.fsize := ns;
        END;
{$IFDEF SYSMEM}
        IF f.has_cache THEN PushPageToCache(f);
{$ENDIF}
        IF f.buf_update THEN BEGIN
                lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
                lWrite(f.f, f.buf^[0], f.buf_count);
                f.buf_update := FALSE;
        END;

        f.buf_page := new_page;
        f.buf_pos := 0;
        f.buf_update := FALSE;

{$IFDEF SYSMEM}
        IF f.has_cache THEN IF GetPageFromCache(f) THEN EXIT;
{$ENDIF}
        lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
        f.buf_count := lRead(f.f, f.buf^[0], SizeOf(BFILE_BUF));
        IF res <> 0 THEN BEGIN
                f.ioresult := 100;
        END;
END;

PROCEDURE SwitchPage(VAR f : BFILE; new_page : DWORD);
BEGIN
        res := 0;
        f.ioresult := 0;

        IF f.buf_page = new_page THEN EXIT;
{$IFDEF SYSMEM}
        IF f.filetype = FS_FILE THEN FsSwitchPage(f, new_page)
        ELSE IF f.filetype = MEM_FILE THEN MemFileSwitchPage(f, new_page);
{$ENDIF}
{$IFNDEF SYSMEM}
        FsSwitchPage(f, new_page);
{$ENDIF}
END;

PROCEDURE BlockWrite(VAR f : BFILE; VAR d; count : WORD);
VAR     p     : PCHAR;
        delta : WORD;
BEGIN
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 105;
                EXIT;
        END;
        f.ioresult := 0;
        res := 0;
        p := @d;
        WHILE count <> 0 DO BEGIN
                delta := SizeOf(BFILE_BUF) - f.buf_pos;
                IF delta = 0 THEN BEGIN
                        SwitchPage(f, f.buf_page + 1);
                        f.buf_pos := 0;
                        { IF f.ioresult <> 0 THEN BREAK; }
                        delta := SizeOf(BFILE_BUF);
                END;
                IF delta > count THEN delta := count;
                Move(p[0], f.buf^[f.buf_pos], delta);
                f.buf_update := TRUE;
                Inc(f.buf_pos, delta);
                Inc(p, delta);
                Dec(count, delta);
                IF f.buf_pos > f.buf_count THEN f.buf_count := f.buf_pos;
        END;
END;

FUNCTION BlockRead(VAR f : BFILE; VAR d; count : WORD) : WORD;
VAR     p     : PCHAR;
        delta : WORD;
        r     : WORD;
BEGIN
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 104;
                EXIT;
        END;
        f.ioresult := 0;
        r := 0;
        res := 0;
        p := @d;
        WHILE count <> 0 DO BEGIN
                delta := f.buf_count - f.buf_pos;
                IF delta = 0 THEN BEGIN
                        SwitchPage(f, f.buf_page + 1);
                        IF f.ioresult <> 0 THEN BREAK;
                        f.buf_pos := 0;
                        IF f.buf_count = 0 THEN BREAK;
                        delta := f.buf_count;
                END;
                IF delta > count THEN delta := count;
                Move(f.buf^[f.buf_pos], p[0], delta);
                Inc(f.buf_pos, delta);
                Dec(count, delta);
                Inc(p, delta);
                Inc(r, delta);
        END;
        BlockRead := r;
END;

PROCEDURE Seek(VAR f : BFILE; pos : DWORD);
BEGIN
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 103;
                EXIT;
        END;
        f.ioresult := 0;
        res := 0;
        SwitchPage(f, pos DIV SizeOf(BFILE_BUF));
        IF f.ioresult = 0 THEN BEGIN
                f.buf_pos := pos MOD SizeOf(BFILE_BUF);
                IF f.buf_count < f.buf_pos THEN f.buf_pos := f.buf_count;
        END;
END;

FUNCTION FilePos(VAR f : BFILE) : DWORD;
BEGIN
        f.ioresult := 0;
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 103;
                FilePos := 0;
        END ELSE FilePos := f.buf_page * SizeOf(BFILE_BUF) + f.buf_pos;
END;

FUNCTION FileSize(VAR f : BFILE) : DWORD;
BEGIN
        f.ioresult := 0;
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 103;
                FileSize := 0;
        END ELSE BEGIN
                UpdateFileSize(f);
                FileSize := f.fsize;
        END;
END;

PROCEDURE FilePosAlign (VAR f : BFILE; align : WORD);
VAR     fpos  : DWORD;
        npos  : DWORD;
        fsize : DWORD;
        m     : WORD;
        buf   : STRING;
BEGIN
        fpos := FilePos(f);
        npos := fpos DIV align;
        m := fpos MOD align;
        IF m = 0 THEN EXIT;
        Inc(npos);
        npos := npos * align;
        fsize := FileSize(f);
        IF fsize >= npos THEN BEGIN Seek(f, npos); EXIT; END;
        IF fpos <> fsize THEN BEGIN
                Seek(f, fsize);
                m := fsize MOD align;
        END;
        FillChar(buf[0], 256, #0);
        m := align - m;
        WHILE m <> 0 DO BEGIN
                IF m > 256 THEN BEGIN
                        BlockWrite(f, buf[0], 256);
                        Dec(m, 256);
                END ELSE BEGIN
                        BlockWrite(f, buf[0], m);
                        m := 0;
                END;
        END;
END;

{$IFDEF SYSMEM}
PROCEDURE swapCachePage(info : POINTER; element1, element2 : WORD);FAR;
VAR     t  : SORT_PAGE;
        m  : PSORT_PAGE_INFO;
BEGIN
        m := PSORT_PAGE_INFO(info);
        t := m^[element1];
        m^[element1] := m^[element2];
        m^[element2] := t;
END;

FUNCTION cmpCachePage(info : POINTER; element1, element2 : WORD) : INTEGER;FAR;
VAR     m  : PSORT_PAGE_INFO;
BEGIN
        m := PSORT_PAGE_INFO(info);
        cmpCachePage := m^[element1].buf_page - m^[element2].buf_page;
END;

PROCEDURE FlushCache(VAR f : BFILE);
VAR     i, cpage, scount  : INTEGER;
        sort_info         : SORT_PAGE_INFO;
BEGIN
        i := 0;
        scount := 0;
        WHILE i < f.cache_size DO BEGIN
                IF f.cache_pages[i].notempty AND f.cache_pages[i].buf_update THEN BEGIN
                        sort_info[scount].buf_page := f.cache_pages[i].buf_page;
                        sort_info[scount].old := i;
                        Inc(scount);
                END;
                Inc(i);
        END;
        IF scount = 0 THEN EXIT;
        Sort(@sort_info, 0, scount - 1, cmpCachePage, swapCachePage);
        i := 0;
        WHILE i < scount DO BEGIN
                cpage := sort_info[i].old;
                f.buf_page := f.cache_pages[cpage].buf_page;
                f.buf_count := f.cache_pages[cpage].buf_count;
                sysmem_get(f.sysmem_ptr, f.cache_pages[cpage].page, f.buf^[0]);
                lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
                lWrite(f.f, f.buf^[0], f.buf_count);
                f.cache_pages[cpage].buf_update := FALSE;
                Inc(i);
        END;
END;
{$ENDIF}

PROCEDURE Flush(VAR f : BFILE);
BEGIN
        IF NOT f.is_open THEN EXIT;
        res := 0;
        f.ioresult := 0;

        IF f.filetype = FS_FILE THEN BEGIN
                IF f.buf_update THEN BEGIN
                        lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
                        lWrite(f.f, f.buf^[0], f.buf_count);
                        f.buf_update := FALSE;
                END;
{$IFDEF SYSMEM}
                IF f.has_cache THEN FlushCache(f);
{$ENDIF}
        END;
END;

PROCEDURE FsClose(VAR f : BFILE);
BEGIN
        lClose(f.f);
        f.is_open := FALSE;
        f.buf_count := 0;
        f.buf_pos := 0;
        f.buf_page := 0;
        f.fsize := 0;
        IF f.delonclose THEN Erase(f);
END;

PROCEDURE Close(VAR f : BFILE);
BEGIN
        res := 0;
        f.ioresult := 0;

        IF NOT f.is_open THEN EXIT;
        IF NOT f.delonclose THEN Flush(f);
        IF f.filetype = FS_FILE THEN FsClose(f);

{$IFDEF SYSMEM}
        IF f.has_cache THEN sysmem_free(f.sysmem_ptr);
{$ENDIF}
        IF f.buf <> NIL THEN FreeMem(f.buf, SizeOf(BFILE_BUF));
        FillChar(f, SizeOf(BFILE), #0);
END;

PROCEDURE Write(VAR f : BFILE; s : STRING);
BEGIN
        BlockWrite(f, s[1], ORD(s[0]));
END;

PROCEDURE WriteLn(VAR f : BFILE; s : STRING);
BEGIN
        BlockWrite(f, s[1], ORD(s[0]));
        IF f.ioresult = 0 THEN BlockWrite(f, LN_STR[1], ORD(LN_STR[0]));
END;

PROCEDURE WriteLnErr (s : STRING);
BEGIN
        lWrite(STDERR, s[1], ORD(s[0]));
        lWrite(STDERR, LN_STR[1], ORD(LN_STR[0]));
END;

PROCEDURE ReadLn(VAR f : BFILE; VAR s : STRING);
VAR     c   : CHAR;
BEGIN
        c := #0;
        s[0] := #0;
        IF NOT f.is_open THEN EXIT;
        WHILE s[0] <> #255 DO BEGIN
                WHILE f.buf_pos < f.buf_count DO BEGIN
                        c := f.buf^[f.buf_pos];
                        Inc(f.buf_pos);
                        IF c <> #$0D THEN BEGIN
                                IF c = #$0A THEN BREAK;
                                Inc(s[0]);
                                s[ORD(s[0])] := c;
                        END;
                END;
                IF (c = #$0A) OR (s[0] = #255) THEN BREAK;
                IF f.buf_pos = f.buf_count THEN BEGIN
                        SwitchPage(f, f.buf_page + 1);
                        IF f.ioresult <> 0 THEN BREAK;
                        f.buf_pos := 0;
                        IF f.buf_count = 0 THEN BREAK;
                END;
        END;
END;

PROCEDURE MemFileTruncate(VAR f : BFILE);
BEGIN
        f.fsize := f.buf_page * SizeOf(BFILE_BUF) + f.buf_pos;
END;

PROCEDURE FsTruncate(VAR f : BFILE);
VAR i    : INTEGER;
BEGIN
        f.fsize := f.buf_page * SizeOf(BFILE_BUF) + f.buf_pos;
        f.buf_count := f.buf_pos;
        res := 0;
        lSeek(f.f, SEEK_BEG, f.fsize);
        lTruncate(f.f);
{$IFDEF SYSMEM}
        IF f.has_cache THEN BEGIN
                i := 0;
                WHILE i < f.cache_size DO BEGIN
                        IF f.cache_pages[i].buf_page > f.buf_page THEN
                                f.cache_pages[i].notempty := FALSE;
                        Inc(i);
                END;
        END;
{$ENDIF}
        f.ioresult := res;
        IF f.ioresult <> 0 THEN BEGIN
                f.ioresult := 101;
                EXIT;
        END;
END;

PROCEDURE Truncate (VAR f : BFILE);
BEGIN
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 105;
                EXIT;
        END;
        f.ioresult := 0;
{$IFDEF SYSMEM}
        IF f.filetype = FS_FILE THEN FsTruncate(f)
        ELSE IF f.filetype = MEM_FILE THEN MemFileTruncate(f);
{$ENDIF}
{$IFNDEF SYSMEM}
        IF f.filetype = FS_FILE THEN FsTruncate(f)
{$ENDIF}
END;

PROCEDURE Erase (VAR f : BFILE);
BEGIN
        IF f.is_open THEN EXIT;
        fname := f.filename + #0;
        lErase;
        f.ioresult := res;
        IF f.ioresult = 0 THEN f.ioresult := 2 ELSE f.ioresult := 0;
END;

FUNCTION BlockCopy (VAR src, dst : BFILE; count : DWORD) : DWORD;
VAR     delta  : WORD;
        fp, fs : DWORD;
BEGIN
        IF (NOT src.is_open) OR (NOT dst.is_open) THEN BEGIN
                BlockCopy := 0;
                EXIT;
        END;
        fs := FileSize(src);
        fp := FilePos(src);
        IF fp + count > fs THEN count := fs - fp;
        fp := 0;
        WHILE count <> 0 DO BEGIN
                delta := src.buf_count - src.buf_pos;
                IF delta = 0 THEN BEGIN
                        SwitchPage(src, src.buf_page + 1);
                        IF src.ioresult <> 0 THEN BREAK;
                        src.buf_pos := 0;
                        delta := src.buf_count;
                END;
                IF delta > count THEN delta := count;
                BlockWrite(dst, src.buf^[src.buf_pos], delta);
                IF dst.ioresult <> 0 THEN BREAK;
                Inc(src.buf_pos, delta);
                Dec(count, delta);
                Inc(fp, delta);
        END;
        BlockCopy := fp;
END;

PROCEDURE SetDefaultCacheSize(i : INTEGER);
BEGIN
{$IFDEF SYSMEM}
        IF i < 0 THEN i := 0; { disable cache }
        IF i > CACHE_PAGES_PER_FILE THEN i := CACHE_PAGES_PER_FILE;
        default_cache_size := i;
{$ENDIF}
END;

FUNCTION ReadByte(VAR f : BFILE) : BYTE;
VAR r : BYTE;
BEGIN
        IF BlockRead(f, r, SizeOf(r)) <> 1 THEN r := 0;
        ReadByte := r;
END;

FUNCTION ReadWord(VAR f : BFILE) : WORD;
VAR     b : ARRAY[0..1] OF BYTE;
        w : WORD;
BEGIN
        w := 0;
        IF BlockRead(f, b, SizeOf(b)) = 2 THEN BEGIN
                w := b[1];
                w := w SHL 8;
                w := w OR b[0];
        END;
        ReadWord := w;
END;

FUNCTION ReadDWord(VAR f : BFILE) : DWORD;
VAR
        b  : ARRAY[0..3] OF BYTE;
        dw : DWORD;
BEGIN
        dw := 0;
        IF BlockRead(f, b, SizeOf(b)) = 4 THEN BEGIN
                dw := b[3] AND $FF;
                dw := dw SHL 8;
                dw := dw OR b[2];
                dw := dw SHL 8;
                dw := dw OR b[1];
                dw := dw SHL 8;
                dw := dw OR b[0];
        END;
        ReadDWord := dw;
END;

PROCEDURE WriteByte(VAR f : BFILE; b : BYTE);
BEGIN
        BlockWrite(f, b, SizeOf(b));
END;

PROCEDURE WriteWord(VAR f : BFILE; w : WORD);
VAR     b : ARRAY[0..1] OF BYTE;
BEGIN
        b[0] := w AND $FF;
        w := w SHR 8;
        b[1] := w AND $FF;
        BlockWrite(f, b, SizeOf(b));
END;

PROCEDURE WriteDWord(VAR f : BFILE; dw : DWORD);
VAR     b : ARRAY[0..3] OF BYTE;
BEGIN
        b[0] := dw AND $FF;
        dw := dw SHR 8;
        b[1] := dw AND $FF;
        dw := dw SHR 8;
        b[2] := dw AND $FF;
        dw := dw SHR 8;
        b[3] := dw AND $FF;
        BlockWrite(f, b, SizeOf(b));
END;

PROCEDURE IncByte(VAR f : BFILE; ofs : DWORD; b : BYTE);
VAR     v   : BYTE;
BEGIN
        Seek(f, ofs);
        v := ReadByte(f);
        Seek(f, ofs);
        WriteByte(f, v + b);
END;

PROCEDURE IncWord(VAR f : BFILE; ofs : DWORD; w : WORD);
VAR     v   : WORD;
BEGIN
        Seek(f, ofs);
        v := ReadWord(f);
        Seek(f, ofs);
        WriteWord(f, v + w);
END;

PROCEDURE IncDWord(VAR f : BFILE; ofs : DWORD; dw : DWORD);
VAR     v   : DWORD;
BEGIN
        Seek(f, ofs);
        v := ReadDWord(f);
        Seek(f, ofs);
        WriteDWord(f, v + dw);
END;

PROCEDURE DecByte(VAR f : BFILE; ofs : DWORD; b : BYTE);
VAR     v   : BYTE;
BEGIN
        Seek(f, ofs);
        v := ReadByte(f);
        Seek(f, ofs);
        WriteByte(f, v - b);
END;

PROCEDURE DecWord(VAR f : BFILE; ofs : DWORD; w : WORD);
VAR     v   : WORD;
BEGIN
        Seek(f, ofs);
        v := ReadWord(f);
        Seek(f, ofs);
        WriteWord(f, v - w);
END;

PROCEDURE DecDWord(VAR f : BFILE; ofs : DWORD; dw : DWORD);
VAR     v   : DWORD;
BEGIN
        Seek(f, ofs);
        v := ReadDWord(f);
        Seek(f, ofs);
        WriteDWord(f, v - dw);
END;

PROCEDURE SetByte(VAR f : BFILE; ofs : DWORD; b : BYTE);
BEGIN
        Seek(f, ofs);
        WriteByte(f, b);
END;

PROCEDURE SetWord(VAR f : BFILE; ofs : DWORD; w : WORD);
BEGIN
        Seek(f, ofs);
        WriteWord(f, w);
END;

PROCEDURE SetDWord(VAR f : BFILE; ofs : DWORD; dw : DWORD);
BEGIN
        Seek(f, ofs);
        WriteDWord(f, dw);
END;

FUNCTION GetByte(VAR f : BFILE; ofs : DWORD) : BYTE;
BEGIN
        Seek(f, ofs);
        GetByte := ReadByte(f);
END;

FUNCTION GetWord(VAR f : BFILE; ofs : DWORD) : WORD;
BEGIN
        Seek(f, ofs);
        GetWord := ReadWord(f);
END;

FUNCTION GetDWord(VAR f : BFILE; ofs : DWORD) : DWORD;
BEGIN
        Seek(f, ofs);
        GetDWord := ReadDWord(f);
END;

PROCEDURE SetDeleteOnClose(VAR f : BFILE; flag : BOOLEAN);
BEGIN
        IF f.is_open AND (f.filetype = FS_FILE) THEN f.delonclose := flag;
END;

PROCEDURE SetUseTempFiles(status : BOOLEAN);
BEGIN
        use_temp := status;
END;

FUNCTION FileExists(s : STRING):BOOLEAN;
VAR h : WORD;
BEGIN
        fname := s + #0;
        h := lReset;
        IF h <> 0 THEN lclose(h);
        FileExists := h <> 0;
END;

PROCEDURE FileDelete(s : STRING);
BEGIN
        fname := s + #0;
        lErase;
END;

FUNCTION GetCurrentDisk : BYTE;ASSEMBLER;
ASM
        MOV  AH, $19
        INT  $21
END;

PROCEDURE SetCurrentDisk(disk : BYTE);ASSEMBLER;
ASM
        MOV  AH, $0e
        MOV  DL, disk
        INT  $21
END;

FUNCTION IsFreeDos : BOOLEAN;ASSEMBLER;
ASM
        MOV  AX, $3000;
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
        MOV  AX,$33FF
        XOR  DX, DX
        INT  $21
        TEST DX, DX
        JNZ  @end
        XOR  AX, AX
        MOV  DX, AX
@end:
END;

{
PROCEDURE MyExitProc;FAR;
BEGIN
        exitProc := prevExitProc;
END;
}

BEGIN
{$IFDEF SYSMEM}
        IF CACHE_PAGES_PER_FILE > 8 THEN default_cache_size := 8
        ELSE default_cache_size := CACHE_PAGES_PER_FILE;
{$ENDIF
        Randomize;
{
        prevExitProc := exitProc;
        exitProc := @MyExitProc;
}
END.
