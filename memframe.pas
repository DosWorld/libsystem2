{ MIT License

Copyright (c) 2025 Viacheslav Komenda

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
{$A-,I-,S-,R-,D+,L+,Q-,F-,G-,O-,B-}
UNIT memframe;

INTERFACE

CONST
MemFrameNodeSize = 32;

TYPE

PMemFrameEntry = ^TMemFrameEntry;
TMemFrameEntry = RECORD
        Pointers : ARRAY[1..MemFrameNodeSize] OF POINTER;
        Sizes    : ARRAY[1..MemFrameNodeSize] OF WORD;
        Count    : INTEGER;
        Next     : PMemFrameEntry;
END;

PMemFrame = ^TMemFrame;
TMemFrame = RECORD
        Head       : PMemFrameEntry;
        NodeCount  : INTEGER;
END;

PROCEDURE Init(VAR Frame: TMemFrame);
FUNCTION Alloc(VAR Frame: TMemFrame; size: Word): POINTER;
PROCEDURE FreeAll(VAR Frame: TMemFrame);

IMPLEMENTATION

PROCEDURE Init(VAR Frame: TMemFrame);
BEGIN
        Frame.Head := NIL;
        Frame.NodeCount := 0;
END;

FUNCTION Alloc(VAR Frame: TMemFrame; size: Word): POINTER;
VAR     CurrentNode: PMemFrameEntry;
        p          : POINTER;
BEGIN
        IF Frame.Head = NIL THEN BEGIN
                New(Frame.Head);
                FillChar(Frame.Head^, SizeOf(TMemFrameEntry), 0);
                Inc(Frame.NodeCount);
        END;

        CurrentNode := Frame.Head;
        WHILE (CurrentNode^.Count = MemFrameNodeSize) AND (CurrentNode^.Next <> NIL) do BEGIN
                CurrentNode := CurrentNode^.Next;
        END;

        IF CurrentNode^.Count = MemFrameNodeSize THEN BEGIN
                New(CurrentNode^.Next);
                FillChar(CurrentNode^.Next^, SizeOf(TMemFrameEntry), 0);
                CurrentNode := CurrentNode^.Next;
                Inc(Frame.NodeCount);
        END;

        GetMem(p, size);
        IF p <> NIL THEN BEGIN
                CurrentNode^.Pointers[CurrentNode^.Count + 1] := p;
                CurrentNode^.Sizes[CurrentNode^.Count + 1] := size;
                Inc(CurrentNode^.Count);
        END;
        Alloc := p;
END;

PROCEDURE FreeAll(VAR Frame: TMemFrame);
VAR     CurrentNode, TempNode: PMemFrameEntry;
        i: INTEGER;
BEGIN
        CurrentNode := Frame.Head;
        WHILE CurrentNode <> NIL DO BEGIN
                FOR i := 1 TO CurrentNode^.Count DO BEGIN
                        IF CurrentNode^.Pointers[i] <> NIL THEN BEGIN
                                FreeMem(CurrentNode^.Pointers[i], CurrentNode^.Sizes[i]);
                                CurrentNode^.Pointers[i] := NIL;
                                CurrentNode^.Sizes[i] := 0;
                        END;
                END;
                TempNode := CurrentNode;
                CurrentNode := CurrentNode^.Next;
                Dispose(TempNode);
        END;
        Frame.Head := NIL;
        Frame.NodeCount := 0;
END;

END.
