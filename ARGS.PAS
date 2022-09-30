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
SOFTWARE. }
{$A+,I-,S-,R-,D+,L+,Q-,F-,G-,O-,B-}
UNIT Args;
{ =========================================================================
  Small unit for command-line parsing.
  Support quoted option values and arguments.

  Produce help-screen via ArgsHelp

  NOTE: Don't open files (or allocate memory) before your call ArgsParse.
  ArgsParse will print help and stop your program, if find '/?' in parameters.

  NOTE: Does not support unicode.

  Command line format
  ==========================================

  NAME.EXE [command] [flags/options] [arguments]

  For example:
  ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
  ³ COOL.EXE create /size=1024 /uppercase file.exe ³
  ÃÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´
  ³ create     ³ command                           ³
  ÃÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´
  ³ /size=1024 ³ string option                     ³
  ³ /uppercase ³ flag                              ³
  ÃÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´
  ³ file.exe   ³ Argument1                         ³
  ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

  Command format
  --------------
  command (without quotes and spaces).

  Options format
  --------------
  string:
  /optName=value
  /optName="value with spaces"

  flag (boolean):
  /optName for TRUE, other case - FALSE

  Arguments format
  ----------------
  filename.ext
  "C:\My Files\long file name.ext"

  Usage example
  ==========================================

        USES args;

        CONST

        a : ARRAY[0..3] OF TOPT = (
        (name : 'o'; otype : OPTSTR; help : 'Set output file name.'),
        (name : 'y'; otype : OPTBOOL; help : 'Boolean opt'),
        (name : 'a'; otype : OPTCMD; help : 'Command type (like add something)'),
        (name : 'd'; otype : OPTCMD; help : 'Command type (like del something)')
        );

        VAR state : TARGSTATE;

        PROCEDURE View;
        VAR i : INTEGER;
        BEGIN
                Writeln('Command is ',GetCmd(state));
        
                FOR i := 1 TO ArgsCount(state) DO
                        Writeln('arg', i, '' : 4, GetArgsStr(state, i));
        
                Writeln('o = ', GetOptStr(state, 'o'));
                Writeln('y = ', GetOptBool(state, 'y'));
        END;
        BEGIN
                ArgsParse(state, a);
                IF ArgsError(state) THEN BEGIN
                        ArgsHelp(state, FALSE);
                        View;
                        Halt(1);
                END;
                View;
        END.

  Example of generated help
  ==========================================

        Usage: RLINK.EXE command [flags/options] arg0 .. argN

        Commands:
         rdf - Link RDF file. Merge all segments into one code segment.
         com - Link COM file, tiny memory model.
         mzs - Link MZ file, small memory model.
         mzh - Link MZ file, huge memory model.

        Flags:
         /bss      Reserve BSS-memory for COM/RDF output.
         /noextmem Use temporary files instead EMS/XMS memory.

        Options:
         /o=<v>     Set output file name.
         /org=<v>   Set code start offset for COM output. (default "0x0100")
         /entry=<v> Set entry-point name. (default "start")
         /s=<v>     Set stack size in KB. (default "8")

        Use /? for help.
  ========================================================================= }
INTERFACE

CONST
MAX_OPTS = 32;

ERR_NO_COMMAND    = 'Command required.';
ERR_OPT_MULTI     = 'You cannt use option multiple times';
ERR_OPT_BAD_NAME  = 'Unavailable option';
ERR_OPT_BAD_VALUE = 'Bad value for option';
ERR_WRONG_COMMAND = 'Command not found';
ERR_BAD_ARG       = 'Bad argument';

TYPE
OPT_TYPE = (OPTSTR , OPTBOOL , OPTCMD);

POPT = ^TOPT;
TOPT = RECORD
        name    : STRING;
        otype   : OPT_TYPE;
        help    : STRING;
        default : STRING[64];
END;

TARGSTATE = RECORD
        opts       : ARRAY[1..MAX_OPTS] OF POPT;
        opts_val   : ARRAY[1..MAX_OPTS] OF BYTE;
        opts_size  : BYTE;
        
        args        : ARRAY[1..MAX_OPTS] OF BYTE;
        opts_count  : BYTE;
        flags_count : BYTE;
        args_count  : BYTE;
        cmds_count  : BYTE;
        cmd         : BYTE;

        error       : BOOLEAN;
        errMsg      : STRING;
        
        cmdl        : STRING;
END;

PROCEDURE ArgsParse(VAR state : TARGSTATE; VAR a : ARRAY OF TOPT);
PROCEDURE ArgsHelp(VAR state : TARGSTATE; stop : BOOLEAN);
FUNCTION GetCmd(VAR state : TARGSTATE) : STRING;

FUNCTION ArgsCount(VAR state : TARGSTATE) : INTEGER;
FUNCTION GetArgsStr(VAR state : TARGSTATE; num : INTEGER) : STRING;

FUNCTION GetOptStr(VAR state : TARGSTATE; name : STRING) : STRING;
FUNCTION GetOptBool(VAR state : TARGSTATE; name : STRING) : BOOLEAN;

FUNCTION ArgsError(VAR state : TARGSTATE) : BOOLEAN;
PROCEDURE SetArgsErr(VAR state : TARGSTATE; msg : STRING);
PROCEDURE WriteArgsErrors(VAR state : TARGSTATE);

IMPLEMENTATION

VAR prevExitProc : POINTER;

TYPE
PSTRING = ^STRING;
PWORD   = ^WORD;

FUNCTION GetSelfName : STRING;
VAR     p : PCHAR;
        c : CHAR;
        i : INTEGER;
        r : STRING;
BEGIN
        r := '';
        p := ptr(PWORD(ptr(PrefixSeg, $2C))^, 0);
        c := #0;
        WHILE NOT ((p[0] = #0) AND (c = #0)) DO BEGIN
                c := p[0];
                Inc(p);
        END;
        Inc(p, 3);

        i := -1;
        WHILE (r[0] <> #255) AND (p[0] <> #0) DO BEGIN
                Inc(r[0]);
                r[ORD(r[0])] := p[0];
                IF p[0] IN [':','/','\'] THEN i := ORD(r[0]);
                Inc(p);
        END;
        IF i <> -1 THEN delete(r, 1, i);
        GetSelfName := r;
END;

FUNCTION GetCmdlStr(VAR state : TARGSTATE; ofs : INTEGER) : STRING;
VAR     r : STRING;
BEGIN
        r := '';
        IF NOT (ofs IN [0, 255, 254]) THEN
                WHILE state.cmdl[ofs] <> #0 DO BEGIN
                        Inc(r[0]);
                        r[ORD(r[0])] := state.cmdl[ofs];
                        Inc(ofs);
                END;
        GetCmdlStr := r;
END;

FUNCTION LookupName(VAR state : TARGSTATE; name : STRING) : INTEGER;
VAR     r, i : INTEGER;
BEGIN
        r := -1; i := 1;
        WHILE (i <= state.opts_size) AND (r = -1) DO BEGIN
                IF state.opts[i]^.name = name THEN r := i;
                Inc(i);
        END;
        LookupName := r;
END;

PROCEDURE ProcessValue(VAR state : TARGSTATE;
        VAR i      : INTEGER;
        len        : INTEGER;
        VAR s      : STRING;
        quoted     : BOOLEAN;
        VAR errMsg : STRING);
VAR     x : INTEGER;
BEGIN
        x := i;
        IF NOT quoted THEN BEGIN
                WHILE (x <= len) AND (s[x] > ' ') DO Inc(x);
                IF i = x THEN SetArgsErr(state, errMsg);
                s[x] := #0;
                Inc(x);
        END ELSE BEGIN
                WHILE (x <= len) AND (s[x] <> '"') DO Inc(x);
                IF (i = x) OR (x > len) THEN SetArgsErr(state, errMsg)
                ELSE IF s[x] <> '"' THEN SetArgsErr(state, errMsg)
                ELSE BEGIN
                        s[x] := #0;
                        Inc(x);
                END;
        END;
        i := x;
END;

PROCEDURE ParseFromLine(VAR state : TARGSTATE; VAR s : STRING);
VAR     i, len      : INTEGER;
        name        : STRING;
        k, value    : INTEGER;
        errMsg      : STRING;
BEGIN
        i := 1; len := Length(s);
        WHILE (i <= len) AND (s[i] <= ' ') DO Inc(i); { skip spaces }
        IF (i <= len) AND (NOT (s[i] IN ['-','/'])) AND (state.cmds_count <> 0) THEN BEGIN
                name := '';
                WHILE (i <= len) AND (s[i] > ' ') DO BEGIN
                        Inc(name[0]);
                        name[ORD(name[0])] := s[i];
                        Inc(i);
                END;
                k := LookupName(state, name);
                IF k = -1 THEN BEGIN
                        SetArgsErr(state, name + ' - ' + ERR_WRONG_COMMAND);
                        EXIT;
                END;
                state.cmd := k;
                WHILE (i <= len) AND (s[i] <= ' ') DO Inc(i); { skip spaces }
        END;
        WHILE (i <= len) AND (s[i] IN ['-','/']) AND (NOT state.error) DO BEGIN
                Inc(i);
                name := ''; value := 0;
                WHILE (i <= len) AND (s[i] > ' ') AND (s[i] <> '=') DO BEGIN
                        Inc(name[0]);
                        name[ORD(name[0])] := s[i];
                        Inc(i);
                END;
                IF name = '?' THEN ArgsHelp(state, TRUE);
                k := LookupName(state, name);
                IF (k = -1) THEN BEGIN
                        SetArgsErr(state, '/' + name + ' - ' + ERR_OPT_BAD_NAME);
                        EXIT;
                END;
                IF NOT (state.opts[k]^.otype IN [OPTSTR,OPTBOOL]) THEN BEGIN
                        SetArgsErr(state, '/' + name + ' - ' + ERR_OPT_BAD_NAME);
                        EXIT;
                END;
                IF state.opts_val[k] <> 0 THEN BEGIN
                        SetArgsErr(state, '/' + name + ' ' + ERR_OPT_MULTI);
                        EXIT;
                END;
                errMsg := ERR_OPT_BAD_VALUE + ' /' + name;
                IF state.opts[k]^.otype = OPTBOOL THEN BEGIN
                        state.opts_val[k] := 255;
                END ELSE IF (i <= len) AND (s[i] = '=') THEN BEGIN
                        Inc(i);
                        IF (i <= len) AND (s[i] <> '"') THEN BEGIN
                                state.opts_val[k] := i;
                                ProcessValue(state, i, len, s, FALSE, errMsg);
                        END ELSE IF (i <= len) AND (s[i] = '"') THEN BEGIN
                                Inc(i);
                                state.opts_val[k] := i;
                                ProcessValue(state, i, len, s, TRUE, errMsg);
                        END ELSE SetArgsErr(state, errMsg);
                END ELSE SetArgsErr(state, errMsg);
                WHILE (i <= len) AND (s[i] <= ' ') DO Inc(i); { skip spaces }
        END;
        WHILE (i <= len) AND (NOT state.error) DO BEGIN
                Inc(state.args_count);
                Str(state.args_count, errMsg);
                errMsg := ERR_BAD_ARG + ' #'+ errMsg;
                IF s[i] = '"' THEN BEGIN
                        Inc(i);
                        IF (i <= len) AND (s[i] IN ['-','/']) THEN BEGIN
                                SetArgsErr(state, errMsg);
                        END ELSE BEGIN
                                state.args[state.args_count] := i;
                                ProcessValue(state, i, len, s, TRUE, errMsg);
                        END;
                END ELSE IF (i <= len) AND (s[i] IN ['-','/']) THEN BEGIN
                                SetArgsErr(state, errMsg);
                END ELSE BEGIN
                        state.args[state.args_count] := i;
                        ProcessValue(state, i, len, s, FALSE, errMsg);
                        
                END;
                WHILE (i <= len) AND (s[i] <= ' ') DO Inc(i); { skip spaces }
        END;
END;

PROCEDURE ArgsParse(VAR state : TARGSTATE; VAR a : ARRAY OF TOPT);
VAR     i : INTEGER;
BEGIN
        FillChar(state, SizeOf(TARGSTATE), #0);
        FOR i := Low(a) TO High(a) DO BEGIN
                Inc(state.opts_size);
                state.opts[state.opts_size] := @a[i];
                IF a[i].otype = OPTCMD THEN Inc(state.cmds_count)
                ELSE IF a[i].otype = OPTBOOL THEN Inc(state.flags_count)
                ELSE Inc(state.opts_count);
        END;
        state.cmdl := PSTRING(ptr(PrefixSeg, $80))^;
        ParseFromLine(state, state.cmdl);
        IF (state.cmds_count <> 0) AND (state.cmd = 0) THEN SetArgsErr(state, ERR_NO_COMMAND);
END;

PROCEDURE ArgsHelp(VAR state : TARGSTATE; stop : BOOLEAN);
VAR     i, maxLen  : INTEGER;
        name       : STRING;
BEGIN
        Write('Usage: ', GetSelfName);
        IF state.cmds_count <> 0 THEN Write(' command');
        IF (state.opts_count + state.flags_count) <> 0 THEN Write(' [flags/options]');
        WriteLn(' arg0 .. argN');
        IF state.cmds_count <> 0 THEN BEGIN
                maxLen := 0;
                FOR i := 1 TO state.opts_size DO
                        IF (maxLen < ORD(state.opts[i]^.name[0]))
                        AND (state.opts[i]^.otype = OPTCMD)
                        THEN maxLen := ORD(state.opts[i]^.name[0]);
                WriteLn;
                WriteLn('Commands:');
                FOR i := 1 TO state.opts_size DO
                IF state.opts[i]^.otype = OPTCMD THEN BEGIN
                        name := state.opts[i]^.name;
                        WHILE ORD(name[0]) < maxLen DO name := name + ' ';
                        Write(' ', name, ' - ');
                        WriteLn(state.opts[i]^.help);
                END;
        END;
        IF state.flags_count <> 0 THEN BEGIN
                maxLen := 0;
                FOR i := 1 TO state.opts_size DO
                        IF (maxLen < ORD(state.opts[i]^.name[0]))
                        AND (state.opts[i]^.otype = OPTBOOL)
                        THEN maxLen := ORD(state.opts[i]^.name[0]);
                Inc(maxLen, 1);
                WriteLn;
                WriteLn('Flags:');
                FOR i := 1 TO state.opts_size DO
                IF state.opts[i]^.otype = OPTBOOL THEN BEGIN
                        name := state.opts[i]^.name;
                        WHILE ORD(name[0]) < maxLen DO name := name + ' ';
                        WriteLn(' /', name, state.opts[i]^.help);
                END;
        END;
        IF state.opts_count <> 0 THEN BEGIN
                maxLen := 0;
                FOR i := 1 TO state.opts_size DO
                        IF (maxLen < ORD(state.opts[i]^.name[0]))
                        AND (state.opts[i]^.otype = OPTSTR)
                        THEN maxLen := ORD(state.opts[i]^.name[0]);
                Inc(maxLen, 5);
                WriteLn;
                WriteLn('Options:');
                FOR i := 1 TO state.opts_size DO
                IF state.opts[i]^.otype = OPTSTR THEN BEGIN
                        name := state.opts[i]^.name + '=<v>';
                        WHILE ORD(name[0]) < maxLen DO name := name + ' ';
                        Write(' /', name, state.opts[i]^.help);
                        IF Length(state.opts[i]^.default) <> 0 THEN
                                Write(' (default "', state.opts[i]^.default, '")');
                        WriteLn;
                END;
        END;
        WriteLn;
        WriteArgsErrors(state);
        IF stop THEN Halt(1);
END;

FUNCTION GetCmd(VAR state : TARGSTATE) : STRING;
BEGIN
        IF state.cmd > 0 THEN 
                GetCmd := state.opts[state.cmd]^.name
        ELSE GetCmd := '';
END;

FUNCTION ArgsCount(VAR state : TARGSTATE) : INTEGER;
BEGIN
        ArgsCount := state.args_count;
END;

FUNCTION GetArgsStr(VAR state : TARGSTATE; num : INTEGER) : STRING;
BEGIN
        IF (num > 0) AND (num <= state.args_count)
                THEN GetArgsStr := GetCmdlStr(state, state.args[num])
        ELSE GetArgsStr := '';
END;

FUNCTION GetOptStr(VAR state : TARGSTATE; name : STRING) : STRING;
VAR i : INTEGER;
    r : STRING;
BEGIN
        i := LookupName(state, name);
        IF i <> -1 THEN BEGIN
                IF state.opts[i]^.otype = OPTSTR THEN BEGIN
                        r := GetCmdlStr(state, state.opts_val[i]);
                        IF Length(r) = 0 THEN r := state.opts[i]^.default;
                END;
        END;
        GetOptStr  := r;
END;

FUNCTION GetOptBool(VAR state : TARGSTATE; name : STRING) : BOOLEAN;
VAR i : INTEGER;
    r : BOOLEAN;
BEGIN
        r := FALSE;
        i := LookupName(state, name);
        IF i <> -1 THEN BEGIN
                IF state.opts[i]^.otype = OPTBOOL THEN BEGIN
                        r := state.opts_val[i] <> 0;
                END;
        END;
        GetOptBool := r;
END;

FUNCTION ArgsError(VAR state : TARGSTATE) : BOOLEAN;
BEGIN
        ArgsError := state.error;
END;

PROCEDURE SetArgsErr(VAR state : TARGSTATE; msg : STRING);
BEGIN
        IF NOT state.error THEN BEGIN
                state.error := TRUE;
                state.errMsg := msg;
        END;
END;

PROCEDURE WriteArgsErrors(VAR state : TARGSTATE);
BEGIN
        IF state.error THEN BEGIN
                WriteLn('ERROR: ', state.errMsg);
        END;
END;

PROCEDURE ArgsExitProc;FAR;
BEGIN
        IF (ErrorAddr = NIL) AND (ExitCode <> 0) THEN BEGIN
                Write('Use /? for help.');
        END;
        exitProc := prevExitProc;
END;

BEGIN
        prevExitProc := exitProc;
        exitProc := @ArgsExitProc;
END.
