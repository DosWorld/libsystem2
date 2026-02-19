{  MIT License

Copyright (c) 2026 Viacheslav Komenda

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
{$I switches.inc}
Unit RdfLoad;

Interface

Type 
PExportSym = ^TExportSym;
TExportSym = Record
        Name: String[32];
        Addr: Pointer;
        Next: PExportSym;
End;

TRDFModule = Record
        CodeBase: Pointer;
        DataBase: Pointer;
        CodeSize: Word;
        DataSize: Word;
        DataRawSize: Word;
        Exports: PExportSym;
End;

Function Load(FileName: String; Var Module: TRDFModule): Boolean;
Function Find(Var Module: TRDFModule; Name: String): Pointer;
Procedure Free(Var Module: TRDFModule);

{ uses rdfload;

type
TProc = procedure;

var Module: TRDFModule;
p : pointer;
testProc : TProc;
begin

        if Load('test.rdf',Module) then begin
                p := Find(Module, 'print_msg');
                if p = nil then writeln('Exported function not found') else begin
                        testProc := TProc(p);
                        testProc;
                end;
        end;
        Free(Module);
end. }

{
bits 16
GLOBAL print_msg

SECTION .data
    db '123'
msg db 'Hello from Linked Module!$'

SECTION .text
print_msg:
    push ds
    mov  ax, seg msg
    mov  ds, ax
    mov  dx, msg
    mov  ah, 09h
    int  21h
    pop  ds
    retf
}

Implementation

uses System2;

Const 
REC_RELOC    = 1;
REC_GLOBAL   = 3;
REC_BSS      = 5;
REC_SEGRELOC = 6;

Type
TRDFHeader = packed Record
        Sign: array[0..5] Of Char;
        ModSize: LongInt;
        HeadSize: LongInt;
End;

TSegHeader = packed Record
        SegType: Word;
        SegNum: Word;
        Reserved: Word;
        Length: LongInt;
End;

TRecHeader = packed Record
        RecType: Byte;
        RecLen: Byte;
End;

Function Align2(Size: Word): Word;
Begin
        If (Size And 1) <> 0 Then Inc(Size);
        Align2 := Size;
End;

Function ExtractString(Var Buf; Offset, MaxLen: Byte): String;
Var     B: array[0..255] Of Byte absolute Buf;
        S: String;
        I: Byte;
Begin
        S := '';
        I := 0;
        While (Offset + I < MaxLen) And (B[Offset + I] <> 0) Do Begin
                S := S + Chr(B[Offset + I]);
                Inc(I);
        End;
        ExtractString := S;
End;

Function GetBSSSize(Var F: BFile; StartPos, EndPos: LongInt): LongInt;
Var     H: TRecHeader;
        Buf: array[0..255] Of Byte;
        Total: LongInt;
        Val: LongInt;
Begin
        Total := 0;
        Seek(F, StartPos);
        While FilePos(F) < EndPos Do Begin
                BlockRead(F, H, SizeOf(H));
                If H.RecLen > 0 Then BlockRead(F, Buf, H.RecLen);
                If H.RecType = REC_BSS Then Begin
                        Move(Buf[0], Val, 4);
                        Total := Total + Val;
                End;
        End;
        GetBSSSize := Total;
End;

Procedure ScanSegments(Var F: BFile; StartPos: LongInt; Var CSize, DSize: LongInt);
Var     SH: TSegHeader;
Begin
        CSize := 0;
        DSize := 0;
        Seek(F, StartPos);
        Repeat
                BlockRead(F, SH, SizeOf(SH));
                If SH.SegType = 1 Then CSize := CSize + SH.Length
                Else If SH.SegType = 2 Then DSize := DSize + SH.Length;
                If SH.Length > 0 Then Seek(F, FilePos(F) + SH.Length);
        Until SH.SegType = 0;
End;

Procedure LoadSegmentData(Var F: BFile; StartPos: LongInt; Var Modul: TRDFModule);
Var     SH: TSegHeader;
Begin
        Seek(F, StartPos);
        Repeat
                BlockRead(F, SH, SizeOf(SH));
                If SH.Length > 0 Then Begin
                        If SH.SegType = 1 Then BlockRead(F, Modul.CodeBase^, Word(SH.Length))
                        Else If SH.SegType = 2 Then BlockRead(F, Modul.DataBase^, Word(SH.Length))
                        Else Seek(F, FilePos(F) + SH.Length);
                End;
        Until SH.SegType = 0;
End;

Procedure ApplyRecords(Var F: BFile; StartPos, EndPos: LongInt; Var Modul: TRDFModule);
Var     H: TRecHeader;
        Buf: array[0..255] Of Byte;
        BaseAddr, TargetPtr, PatchAddr: Pointer;
        RelFlags, RelWidth, GSegID: Byte;
        RelOffset, GOffset: LongInt;
        RelRSeg: Word;
        PatchVal: Word;
        NewSym: PExportSym;
Begin
        Seek(F, StartPos);
        While FilePos(F) < EndPos Do Begin
        BlockRead(F, H, SizeOf(H));
        If H.RecLen > 0 Then BlockRead(F, Buf, H.RecLen);
        Case H.RecType Of 
        REC_RELOC, REC_SEGRELOC:
                                 Begin
                                   RelFlags := Buf[0];
                                   Move(Buf[1], RelOffset, 4);
                                   RelWidth := Buf[5];
                                   Move(Buf[6], RelRSeg, 2);

                                   If (RelFlags And $0F) = 0 Then BaseAddr := Modul.CodeBase
                                   Else BaseAddr := Modul.DataBase;

                                   PatchAddr := Ptr(Seg(BaseAddr^), Ofs(BaseAddr^) + Word(RelOffset)
                                                );

                                   If RelRSeg = 0 Then TargetPtr := Modul.CodeBase
                                   Else If RelRSeg = 1 Then TargetPtr := Modul.DataBase
                                   Else If RelRSeg = 2 Then TargetPtr := Ptr(Seg(Modul.DataBase^),
                                                                         Ofs(Modul.DataBase^) +
                                                                         Modul.DataRawSize)
                                   Else TargetPtr := Modul.DataBase;

                                   If H.RecType = REC_RELOC Then
                                     Begin
                                       If RelWidth = 2 Then
                                         Begin
                                           PatchVal := Ofs(TargetPtr^);
                                           Inc(Word(PatchAddr^), PatchVal);
                                         End;
                                     End
                                   Else
                                     Begin
                                       If RelWidth = 2 Then
                                         Word(PatchAddr^) := Seg(TargetPtr^);
                                     End;
                End;

        REC_GLOBAL:
                    Begin
                      GSegID := Buf[1];
                      Move(Buf[2], GOffset, 4);

                      New(NewSym);
                      NewSym^.Name := ExtractString(Buf, 6, H.RecLen);
                      NewSym^.Next := Modul.Exports;
                      Modul.Exports := NewSym;

                      If GSegID = 0 Then
                        NewSym^.Addr := Ptr(Seg(Modul.CodeBase^), Ofs(Modul.CodeBase^) + Word(
                                        GOffset))
                      Else If GSegID = 2 Then
                             NewSym^.Addr := Ptr(Seg(Modul.DataBase^), Ofs(Modul.DataBase^) + Modul.
                                             DataRawSize + Word(GOffset))
                      Else
                        NewSym^.Addr := Ptr(Seg(Modul.DataBase^), Ofs(Modul.DataBase^) + Word(
                                        GOffset));
                    End;
                End;
        End;
End;

Function Load(FileName: String; Var Module: TRDFModule): Boolean;
Var     F: BFile;
        Hdr: TRDFHeader;
        RecStart, SegStart: LongInt;
        RCSize, RDSize, RBSize: LongInt;
        i : integer;
Begin
        Load := False;
        FillChar(Module, SizeOf(Module), 0);
        Assign(F, FileName);
        Reset(F); {$I-} i := IOResult; {$I+}
        If i <> 0 Then Exit;

        BlockRead(F, Hdr, SizeOf(Hdr));
        If Hdr.Sign <> 'RDOFF2' Then Begin
                Close(F);
                Exit;
        End;
        RecStart := FilePos(F);
        SegStart := RecStart + Hdr.HeadSize;
        RBSize := GetBSSSize(F, RecStart, SegStart);
        ScanSegments(F, SegStart, RCSize, RDSize);

        If (RCSize > 65520) Or ((RDSize + RBSize) > 65520) Then Begin
                Close(F);
                Exit;
        End;
        Module.CodeSize := Align2(Word(RCSize));
        Module.DataSize := Align2(Word(RDSize + RBSize));
        Module.DataRawSize := Word(RDSize);
        If Module.CodeSize > 0 Then GetMem(Module.CodeBase, Module.CodeSize);
        If Module.DataSize > 0 Then Begin
                GetMem(Module.DataBase, Module.DataSize);
                FillChar(Module.DataBase^, Module.DataSize, 0);
        End;
        LoadSegmentData(F, SegStart, Module);
        ApplyRecords(F, RecStart, SegStart, Module);
        Close(F);
        Load := True;
End;

Function Find(Var Module: TRDFModule; Name: String): Pointer;
Var     Current: PExportSym;
Begin
        Current := Module.Exports;
        While Current <> Nil Do Begin
                If Current^.Name = Name Then Begin
                        Find := Current^.Addr;
                        Exit;
                End;
                Current := Current^.Next;
        End;
        Find := Nil;
End;

Procedure Free(Var Module: TRDFModule);
Var     Temp, Next: PExportSym;
Begin
        Temp := Module.Exports;
        While Temp <> Nil Do Begin
                Next := Temp^.Next;
                Dispose(Temp);
                Temp := Next;
        End;
        Module.Exports := Nil;
        If (Module.CodeSize > 0) And (Module.CodeBase <> Nil) Then FreeMem(Module.CodeBase, Module.CodeSize);
        If (Module.DataSize > 0) And (Module.DataBase <> Nil) Then FreeMem(Module.DataBase, Module.DataSize);
        FillChar(Module, SizeOf(Module), 0);
End;

End.
