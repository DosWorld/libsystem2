UNIT dynstr;

INTERFACE

USES memframe;

TYPE
PString = ^TString;
TString = RECORD
        Len      : WORD;
        Capacity : WORD;
        Frame    : PMemFrame;
        Data     : PCHAR;
END;

PROCEDURE InitStr(VAR S: TString; Frame : PMemFrame; InitialCapacity: WORD);
PROCEDURE AppendStr(VAR S: TString; Str: PCHAR);
PROCEDURE InsertStr(VAR S: TString; Str: PCHAR; Position: WORD);
PROCEDURE ClearStr(VAR S: TString);
PROCEDURE FreeStr(VAR S: TString);
PROCEDURE DeleteSubStr(VAR S: TString; BeginIdx, len: WORD);
PROCEDURE Substring(VAR S: TString; BeginIdx, len: WORD; VAR SubStr: TString);
FUNCTION CompareStr(S1, S2: TString): INTEGER;

IMPLEMENTATION

USES cstring;

PROCEDURE InitStr(VAR S: TString; Frame : PMemFrame; InitialCapacity: WORD);
BEGIN
        IF InitialCapacity = 0 THEN InitialCapacity := 16;
        S.Len := 0;
        S.Capacity := InitialCapacity;
        S.Frame := Frame;
        GetMem(S.Data, S.Capacity);
        S.Data[0] := #0;
END;

PROCEDURE ResizeString(VAR S: TString; NewCapacity: WORD);
VAR     NewData: PCHAR;
BEGIN
        IF S.Frame = NIL THEN GetMem(NewData, NewCapacity)
        ELSE NewData := Alloc(S.Frame^, NewCapacity);

        Move(S.Data^, NewData^, S.Len + 1);
        IF S.Frame = NIL THEN FreeMem(S.Data, S.Capacity);
        S.Data := NewData;
        S.Capacity := NewCapacity;
END;

PROCEDURE AppendStr(VAR S: TString; Str: PCHAR);
VAR     NewLen: WORD;
BEGIN
        NewLen := S.Len + StrLen(Str);
        IF NewLen + 1 > S.Capacity THEN ResizeString(S, NewLen + 32);
        StrCat(S.Data, Str);
        S.Len := NewLen;
END;

PROCEDURE InsertStr(VAR S: TString; Str: PCHAR; Position: WORD);
VAR     InsertLen, NewLen: WORD;
BEGIN
        IF Position > S.Len THEN EXIT;

        InsertLen := StrLen(Str);
        NewLen := S.Len + InsertLen;
        IF NewLen > S.Capacity THEN ResizeString(S, NewLen * 2);
        Move(S.Data[Position], S.Data[Position + InsertLen], S.Len - Position + 1);
        Move(Str^, S.Data[Position], InsertLen);
        S.Len := NewLen;
END;

PROCEDURE ClearStr(VAR S: TString);
BEGIN
        S.Len := 0;
        IF S.Data <> nil THEN S.Data[0] := #0;
END;

PROCEDURE FreeStr(VAR S: TString);
BEGIN
        IF S.Data <> nil THEN BEGIN
                IF S.Frame = NIL THEN FreeMem(S.Data, S.Capacity);
                S.Data := nil;
        END;
        S.Len := 0;
        S.Capacity := 0;
END;

PROCEDURE DeleteSubStr(VAR S: TString; BeginIdx, len: WORD);
BEGIN
        IF (BeginIdx >= S.Len) OR (len = 0) THEN EXIT;
        IF BeginIdx + len > S.Len THEN len := S.Len - BeginIdx;

        Move(S.Data[BeginIdx + len], S.Data[BeginIdx], S.Len - BeginIdx - len + 1);
        S.Len := S.Len - len;
        S.Data[S.Len] := #0;
END;

PROCEDURE SubString(VAR S: TString; BeginIdx, len: WORD; VAR SubStr: TString);
BEGIN
        IF (BeginIdx >= S.Len) OR (len = 0) THEN BEGIN
                ClearStr(SubStr);
                EXIT;
        END;
        IF BeginIdx + len > S.Len THEN len := S.Len - BeginIdx;
        ClearStr(SubStr);
        ResizeString(SubStr, len + 1);
        Move(S.Data[BeginIdx], SubStr.Data^, len);
        SubStr.Data[len] := #0;
        SubStr.Len := len;
END;

FUNCTION CompareStr(S1, S2: TString): INTEGER;
BEGIN
        IF S1.Len <> S2.Len THEN CompareStr := S1.Len - S2.Len
        ELSE CompareStr := StrCmp(S1.Data, S2.Data);
END;

{ ----------------------------------------------------------------------
tests
  ----------------------------------------------------------------------
VAR     S, SubStr: TString;

PROCEDURE TestInit;
BEGIN
        InitStr(S, 10);
        IF (S.Len <> 0) OR (S.Capacity <> 10) OR (S.Data = nil) THEN
          Writeln('TestInit failed') ELSE Writeln('TestInit passed');
END;

PROCEDURE TestAppend;
BEGIN
        AppendStr(S, 'Hello world');
        IF (S.Len <> 5) OR (StrCmp(S.Data, 'Hello') <> 0) THEN
          Writeln('TestAppend failed') ELSE Writeln('TestAppend passed'); 
END;

PROCEDURE TestInsert;
BEGIN
        InsertStr(S, ' World', 5);
        IF (S.Len <> 11) OR (StrCmp(S.Data, 'Hello World') <> 0) THEN
          Writeln('TestInsert failed') ELSE Writeln('TestInsert passed');
END;

PROCEDURE TestDelete;
BEGIN
        DeleteSubStr(S, 5, 6);
        IF (S.Len <> 5) OR (StrCmp(S.Data, 'Hello') <> 0) THEN
          Writeln('TestDelete failed') ELSE Writeln('TestDelete passed');
END;

PROCEDURE TestSubstring;
BEGIN
        AppendStr(S, ' World');
        Substring(S, 6, 5, SubStr);
        IF (SubStr.Len <> 5) OR (StrCmp(SubStr.Data, 'World') <> 0) THEN
          Writeln('TestSubstring failed') ELSE Writeln('TestSubstring passed');
END;

PROCEDURE TestCompare;
VAR     S2: TString;
BEGIN
        InitStr(S2, 10);
        AppendStr(S2, 'Hello');
        IF CompareStr(S, S2) <> 0 THEN
          Writeln('TestCompare failed') ELSE Writeln('TestCompare passed');
        FreeStr(S2);
END;

PROCEDURE TestClear;
BEGIN
        ClearStr(S);
        IF (S.Len <> 0) OR (StrCmp(S.Data, '') <> 0) THEN
          Writeln('TestClear failed') ELSE Writeln('TestClear passed');
END;

PROCEDURE TestFree;
BEGIN
        FreeStr(S);
        IF (S.Len <> 0) OR (S.Capacity <> 0) OR (S.Data <> nil) THEN
          Writeln('TestFree failed') ELSE Writeln('TestFree passed');
END;

BEGIN
  TestInit;
  TestAppend;
  TestInsert;
  TestDelete;
  TestSubstring;
  TestCompare;
  TestClear;
  TestFree;
}
END.
