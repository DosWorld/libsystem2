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
UNIT System2;
{ =========================================================================
  Hi !

  This units is designed to replace some functions from system unit.
  It has support for:

  1. Long file names
  2. Buffered I/O (DOS memory, 16K per file).
  3. Temporary files.
  4. Quoted command-line parameters.

  NOTE about 16K: This value became from EMS-page size,
  so please dont change it.

  ========================================================================= }
INTERFACE

{$DEFINE USE_CACHE}

{$IFDEF DPMI}
        {$UNDEF USE_CACHE}
{$ENDIF}
{$IFDEF WINDOWS}
        {$UNDEF USE_CACHE}
{$ENDIF}
{$IFDEF LINUX}
        {$UNDEF USE_CACHE}
{$ENDIF}
{$IFDEF OS2}
        {$UNDEF USE_CACHE}
{$ENDIF}

CONST
BFILE_BUF_SIZE = $4000;

TYPE
TFILETYPE = (FS_FILE);
DWORD = LONGINT;
BFILE_BUF = ARRAY[0..BFILE_BUF_SIZE - 1] OF CHAR;

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
{$IFDEF USE_CACHE}
        rcache      : POINTER;
        wcache      : POINTER;
{$ENDIF}
        delonclose  : BOOLEAN;
END;

PROCEDURE Assign (VAR f : BFILE; fname : STRING);
PROCEDURE Reset (VAR f : BFILE);
PROCEDURE ReWrite (VAR f : BFILE);
PROCEDURE Append (VAR f : BFILE);

{ ReWriteTemp does not requre call to Assign }
PROCEDURE ReWriteTemp (VAR f : BFILE);

{ Console EOF, for case when input is redirected }
FUNCTION cEof : BOOLEAN;

FUNCTION Eof (VAR f : BFILE) : BOOLEAN;
PROCEDURE Flush (VAR f : BFILE);

{ Set flag - delete file, when close }
PROCEDURE SetDeleteOnClose(VAR f : BFILE; flag : BOOLEAN);
PROCEDURE Close (VAR f : BFILE);
FUNCTION IsOpen(VAR f : BFILE):BOOLEAN;

FUNCTION ReadByte(VAR f : BFILE) : BYTE;
FUNCTION ReadInteger(VAR f : BFILE) : INTEGER;
FUNCTION ReadWord(VAR f : BFILE) : WORD;
FUNCTION ReadDWord(VAR f : BFILE) : DWORD;
PROCEDURE ReadLn (VAR f : BFILE; VAR s : STRING);
PROCEDURE ReadAsciiz(VAR f : BFile; VAR s : STRING);
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

FUNCTION FileExists(s : STRING):BOOLEAN;
PROCEDURE FileDelete(s : STRING);

FUNCTION GetCurrentDisk : BYTE;
PROCEDURE SetCurrentDisk(disk : BYTE);

IMPLEMENTATION

USES Dos {$IFDEF USE_CACHE}, ExCache{$ENDIF};

CONST
STDIN  = 0;
STDOUT = 1;
STDERR = 2;

SEEK_BEG = 0;
SEEK_CUR = 1;
SEEK_END = 2;

LN_STR : STRING[2] = #$0D + #$0A;
SELFNAME : PCHAR = NIL;

{$IFDEF USE_CACHE}
READ_CACHE_SIZE  = 8;
WRITE_CACHE_SIZE = 8;
{$ENDIF}

TYPE
PSTRING = ^STRING;
PWORD   = ^WORD;

VAR     fname              : STRING;
        fname2             : STRING;
        res                : WORD;
        prevExitProc       : POINTER;

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
        IF NOT (s[ORD(s[0])] IN ['\', '/']) THEN s := s + '\';
END;

FUNCTION cEof : BOOLEAN;ASSEMBLER;
ASM
        MOV  AX, $4406
        XOR  BX, BX
        INT  $21
        JC   @err
        OR   AL, AL
        JZ   @err
        XOR  AX, AX
        JMP  @end
@err:
        XOR  AX, AX
        DEC  AX
@end:
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

FUNCTION GetSelfName(psp_seg : WORD; VAR sname : PCHAR) : STRING;
VAR     r   : STRING;
        c   : CHAR;
        p   : PCHAR;
BEGIN
        r[0] := #0;
        IF sname = NIL THEN BEGIN
                sname := ptr(PWORD(ptr(psp_seg, $2C))^, 0);
                c := #0;
                WHILE NOT ((sname[0] = #0) AND (c = #0)) DO BEGIN
                        c := sname[0];
                        Inc(sname, 1);
                END;
                Inc(sname, 3);
        END;
        IF sname <> NIL THEN BEGIN
                p := sname;
                WHILE r[0] <> #255 DO BEGIN
                        IF p[0] = #0 THEN BREAK;
                        Inc(r[0]);
                        r[ORD(r[0])] := p[0];
                        Inc(p);
                END;
        END;
        GetSelfName := r;
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
                r := GetSelfName(PrefixSeg, SELFNAME);
        END;
        ParamStr := r;
END;

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
{$IFDEF USE_CACHE}
        IF f.is_open THEN BEGIN
                f.rcache := excache_create(READ_CACHE_SIZE);
                f.wcache := excache_create(WRITE_CACHE_SIZE);
        END;
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
        f.filetype := FS_FILE;
        IF f.is_open THEN BEGIN
                lSeek(f.f, SEEK_END, 0);
                f.fsize := lTell(f.f);
                lSeek(f.f, SEEK_BEG, 0);
                f.buf_count := lRead(f.f, f.buf^, SizeOf(BFILE_BUF));
                if res <> 0 THEN f.ioresult := 100;
        END;
{$IFDEF USE_CACHE}
        IF f.is_open THEN BEGIN
                f.rcache := excache_create(READ_CACHE_SIZE);
                f.wcache := excache_create(WRITE_CACHE_SIZE);
        END;
{$ENDIF}
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

PROCEDURE UpdateFileSize(VAR f : BFILE);
VAR     ns : DWORD;
BEGIN
        ns := DWORD(f.buf_page) * SizeOf(BFILE_BUF) + f.buf_count;
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


PROCEDURE FsSwitchPage(VAR f : BFILE; new_page : DWORD);
VAR     ns        : DWORD;
        csize     : WORD;
BEGIN
        IF f.buf_update THEN UpdateFileSize(f);
{$IFDEF USE_CACHE}
        IF (f.wcache <> NIL) AND (f.rcache <> NIL) THEN BEGIN
                IF f.buf_update THEN BEGIN
                        IF excache_Put(PEXCACHE(f.wcache), f.buf_page, f.buf^, f.buf_count) THEN BEGIN
                                IF excache_IsFull(PEXCACHE(f.wcache)) THEN BEGIN
                                        csize := excache_Size(PEXCACHE(f.wcache));
                                        f.buf_page := PEXCACHE(f.wcache)^.items[csize].recno;
                                        excache_Get(PEXCACHE(f.wcache), f.buf_page, f.buf^, f.buf_count);
                                        excache_Put(PEXCACHE(f.rcache), f.buf_page, f.buf^, f.buf_count);
                                        f.buf_update := TRUE;
                                END ELSE f.buf_update := FALSE;
                        END;
                END ELSE excache_Put(PEXCACHE(f.rcache), f.buf_page, f.buf^, f.buf_count);
        END;
{$ENDIF}
        IF f.buf_update THEN BEGIN
                lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
                lWrite(f.f, f.buf^, f.buf_count);
                f.buf_update := FALSE;
        END;

        f.buf_page := new_page;
        f.buf_pos := 0;
{$IFDEF USE_CACHE}
        IF (f.rcache <> NIL) AND excache_Get(PEXCACHE(f.rcache), f.buf_page, f.buf^, f.buf_count) THEN BEGIN
                f.buf_update := FALSE;
        END ELSE IF (f.wcache <> NIL) AND excache_Get(PEXCACHE(f.wcache), f.buf_page, f.buf^, f.buf_count) THEN BEGIN
                f.buf_update := TRUE;
        END ELSE BEGIN
                f.buf_update := FALSE;
                lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
                f.buf_count := lRead(f.f, f.buf^, SizeOf(BFILE_BUF));
        END;
{$ENDIF}
{$IFNDEF USE_CACHE}
        f.buf_update := FALSE;
        lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
        f.buf_count := lRead(f.f, f.buf^, SizeOf(BFILE_BUF));
{$ENDIF}
        IF res <> 0 THEN BEGIN
                f.ioresult := 100;
        END;
END;

PROCEDURE SwitchPage(VAR f : BFILE; new_page : DWORD);
BEGIN
        res := 0;
        f.ioresult := 0;

        IF f.buf_page = new_page THEN EXIT;
        FsSwitchPage(f, new_page);
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
                        IF f.ioresult <> 0 THEN BREAK;
                        delta := SizeOf(BFILE_BUF);
                END;
                IF delta > count THEN delta := count;
                Move(p^, f.buf^[f.buf_pos], delta);
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
                        f.buf_pos := 0;
                        IF f.buf_count = 0 THEN BREAK;
                        delta := f.buf_count;
                END;
                IF delta > count THEN delta := count;
                Move(f.buf^[f.buf_pos], p^, delta);
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
        END ELSE FilePos := DWORD(f.buf_page) * SizeOf(BFILE_BUF) + f.buf_pos;
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

PROCEDURE Flush(VAR f : BFILE);
VAR     i        : INTEGER;
        bp       : DWORD;
        bc       : WORD;
        buf_used : BOOLEAN;
BEGIN
        IF NOT f.is_open THEN EXIT;
        res := 0;
        f.ioresult := 0;

        IF f.filetype = FS_FILE THEN BEGIN
{$IFDEF USE_CACHE}
                IF f.buf_update THEN BEGIN
                        f.buf_update := NOT excache_put(PEXCACHE(f.wcache), f.buf_page, f.buf^, f.buf_count);
                END;
{$ENDIF}
                IF f.buf_update THEN BEGIN
                        lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
                        lWrite(f.f, f.buf^, f.buf_count);
                        f.buf_update := FALSE;
                END;
{$IFDEF USE_CACHE}
                buf_used := FALSE;
                excache_put(PEXCACHE(f.rcache), f.buf_page, f.buf^, f.buf_count);
                FOR i := 1 TO excache_size(PEXCACHE(f.wcache)) DO BEGIN
                        IF PEXCACHE(f.wcache)^.items[i].is_busy THEN BEGIN
                                bp := PEXCACHE(f.wcache)^.items[i].recno;
                                bc := PEXCACHE(f.wcache)^.items[i].count;
                                excache_get(PEXCACHE(f.wcache), bp, f.buf^, bc);
                                lSeek(f.f, SEEK_BEG, bp * SizeOf(BFILE_BUF));
                                lWrite(f.f, f.buf^, bc);
                                buf_used := TRUE;
                        END;
                END;
                IF NOT excache_get(PEXCACHE(f.rcache), f.buf_page, f.buf^, f.buf_count) THEN BEGIN
                        IF buf_used THEN BEGIN
                                lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
                                lRead(f.f, f.buf^, f.buf_count);
                        END;
                END;
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
{$IFDEF USE_CACHE}
        excache_free(PEXCACHE(f.rcache));
        excache_free(PEXCACHE(f.wcache));
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

PROCEDURE ReadAsciiz(VAR f : BFile; VAR s : STRING);
VAR     p       : LONGINT;
BEGIN
        p := FilePos(f);
        BlockRead(f, s[1], 255);
        s[0] := #0;
        WHILE s[0] < #255 DO BEGIN
                IF s[ord(s[0]) + 1] = #0 THEN BREAK;
                Inc(s[0]);
        END;
        Seek(f, p + ord(s[0]) + 1);
END;

PROCEDURE ReadLn(VAR f : BFILE; VAR s : STRING);
VAR     c           : CHAR;
        p           : PCHAR;
        tstr        : STRING;
BEGIN
        IF NOT f.is_open THEN EXIT;
        tstr[0] := #0;
        c := #0;
        WHILE (c <> #$0A) AND (tstr[0] <> #255) DO BEGIN
                p := @f.buf^[f.buf_pos];
                c := #0;
                WHILE (f.buf_pos < f.buf_count) AND (tstr[0] < #255) DO BEGIN
                        c := p^;
                        Inc(p);
                        Inc(f.buf_pos);
                        IF c <> #$0D THEN BEGIN
                                IF c = #$0A THEN BREAK;
                                Inc(tstr[0]);
                                tstr[ORD(tstr[0])] := c;
                        END;
                END;
                IF f.buf_pos = f.buf_count THEN BEGIN
                        SwitchPage(f, f.buf_page + 1);
                        IF f.ioresult <> 0 THEN BREAK;
                        f.buf_pos := 0;
                        IF f.buf_count = 0 THEN BREAK;
                END;
        END;
        s := tstr;
END;

PROCEDURE FsTruncate(VAR f : BFILE);
VAR i    : INTEGER;
BEGIN
        f.fsize := f.buf_page * SizeOf(BFILE_BUF) + f.buf_pos;
        f.buf_count := f.buf_pos;
{$IFDEF USE_CACHE}
        IF f.rcache <> NIL THEN excache_truncate(PEXCACHE(f.rcache), f.buf_page, f.buf_count);
        IF f.wcache <> NIL THEN excache_truncate(PEXCACHE(f.wcache), f.buf_page, f.buf_count);
{$ENDIF}
        res := 0;
        lSeek(f.f, SEEK_BEG, f.fsize);
        lTruncate(f.f);
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
        IF f.filetype = FS_FILE THEN FsTruncate(f)
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

FUNCTION ReadByte(VAR f : BFILE) : BYTE;
VAR r : BYTE;
BEGIN
        IF BlockRead(f, r, SizeOf(r)) <> 1 THEN r := 0;
        ReadByte := r;
END;

FUNCTION ReadInteger(VAR f : BFILE) : INTEGER;
VAR     b : ARRAY[0..1] OF BYTE;
        i : INTEGER;
BEGIN
        i := 0;
        IF BlockRead(f, b, SizeOf(b)) = 2 THEN BEGIN
                i := b[1];
                i := i SHL 8;
                i := i OR b[0];
        END;
        ReadInteger := i;
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

{
PROCEDURE MyExitProc;FAR;
BEGIN
        exitProc := prevExitProc;
END;
}

BEGIN
        Randomize;
{
        prevExitProc := exitProc;
        exitProc := @MyExitProc;
}
END.
