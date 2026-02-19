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
{$I switches.inc}
UNIT DynArr;

INTERFACE

USES memframe;

TYPE
DYNARR_FILE = FILE;

PArray = ^TArray;
TArray = RECORD
        Data        : POINTER;
        Size        : WORD;
        Capacity    : WORD;
        ElementSize : WORD;
        MemFrame    : PMemFrame;
END;

PROCEDURE Init(VAR Arr : TArray; ElementSize : WORD; MemFrame : PMemFrame);
PROCEDURE Reset(VAR Arr : TArray);
PROCEDURE Free(VAR Arr : TArray);

PROCEDURE SetLength(VAR Arr : TArray; NewLength : WORD);
FUNCTION GetLength(VAR Arr : TArray)  : WORD;
PROCEDURE Delete(VAR Arr : TArray; StartIndex, Count: WORD);

PROCEDURE Clear(VAR Arr : TArray; StartIndex, Count: WORD);
PROCEDURE Insert(VAR Arr : TArray; Index: WORD; VAR Element);
PROCEDURE Add(VAR Arr : TArray; VAR Element);
PROCEDURE Get(VAR Arr : TArray; Index : WORD; VAR Element);
FUNCTION GetPtr(VAR Arr : TArray; Index : WORD) : POINTER;
PROCEDURE Put(VAR Arr : TArray; Index : WORD; VAR Element);
PROCEDURE Swap(VAR Arr : TArray; Index1, Index2 : WORD);

PROCEDURE Copy(VAR SourceArr, DestArr : TArray);
PROCEDURE InsertAll(VAR SourceArr : TArray; SourceStartIndex, Count: WORD; VAR DestArr : TArray; DestStartIndex : WORD);

IMPLEMENTATION

CONST
ALLOC_STEP = 16;
MAGIC      = $4411;

PROCEDURE Init(VAR Arr : TArray; ElementSize : WORD; MemFrame : PMemFrame);
BEGIN
        FillChar(Arr, SizeOf(TArray), #0);
        Arr.ElementSize := ElementSize;
        Arr.MemFrame := MemFrame;
END;

PROCEDURE Free(VAR Arr : TArray);
BEGIN
        IF Arr.MemFrame <> NIL THEN EXIT;
        IF Arr.Data <> NIL THEN FreeMem(Arr.Data, Arr.Capacity * Arr.ElementSize);
        Arr.Data := nil;
        Arr.Size := 0;
        Arr.Capacity := 0;
END;

PROCEDURE Reset(VAR Arr : TArray);
BEGIN
        Arr.Size := 0;
END;

PROCEDURE Clear(VAR Arr : TArray; StartIndex, Count: WORD);
BEGIN
        IF (StartIndex >= Arr.Size) OR (Count = 0) THEN EXIT;
        IF (StartIndex + Count > Arr.Size) THEN Count := Arr.Size - StartIndex;
        FillChar((PCHAR(Arr.Data) + StartIndex * Arr.ElementSize)^
        , Count * Arr.ElementSize
        , #0);
END;

PROCEDURE ChangeCapacity(VAR Arr : TArray; NewCapacity : WORD);
VAR     NewData : PCHAR;
BEGIN
        IF NewCapacity = 0 THEN Reset(Arr)
        ELSE BEGIN
                IF Arr.MemFrame = NIL THEN GetMem(NewData, NewCapacity * Arr.ElementSize)
                ELSE NewData := Alloc(Arr.MemFrame^, NewCapacity * Arr.ElementSize);
                IF NewData <> NIL THEN BEGIN
                        IF Arr.Data <> nil THEN BEGIN
                                Move(PCHAR(Arr.Data)^, NewData^, Arr.Size * Arr.ElementSize);
                                IF NewCapacity > Arr.Size THEN
                                      FillChar(NewData[Arr.Size * Arr.ElementSize]
                                      , (NewCapacity - Arr.Size) * Arr.ElementSize
                                      , #0);
                                IF Arr.MemFrame = NIL THEN FreeMem(Arr.Data, Arr.Capacity * Arr.ElementSize);
                        END;
                        Arr.Data := NewData;
                        Arr.Capacity := NewCapacity;
                END;
        END;
END;

PROCEDURE Add(VAR Arr : TArray; VAR Element);
BEGIN
        IF Arr.Size = Arr.Capacity THEN ChangeCapacity(Arr, Arr.Capacity + ALLOC_STEP);
        Move(Element
        , (PCHAR(Arr.Data) + Arr.Size * Arr.ElementSize)^
        , Arr.ElementSize);
        INC(Arr.Size);
END;

PROCEDURE Delete(VAR Arr : TArray; StartIndex, Count: WORD);
BEGIN
        IF (StartIndex >= Arr.Size) OR (Count = 0) THEN EXIT;
        IF (StartIndex + Count > Arr.Size) THEN Count := Arr.Size - StartIndex;
        IF StartIndex + Count < Arr.Size THEN
                Move((PCHAR(Arr.Data) + (StartIndex + Count) * Arr.ElementSize)^
                , (PCHAR(Arr.Data) + StartIndex * Arr.ElementSize)^
                , (Arr.Size - StartIndex - Count) * Arr.ElementSize);
        DEC(Arr.Size, Count);
        IF Arr.Size + ALLOC_STEP < Arr.Capacity - ALLOC_STEP * 2 THEN 
                ChangeCapacity(Arr, Arr.Size + ALLOC_STEP);
END;

PROCEDURE Get(VAR Arr : TArray; Index : WORD; VAR Element);
BEGIN
        IF Index >= Arr.Size THEN EXIT;
        Move((PCHAR(Arr.Data) + Index * Arr.ElementSize)^
        , Element
        , Arr.ElementSize);
END;

FUNCTION GetPtr(VAR Arr : TArray; Index : WORD) : POINTER;
BEGIN
        IF Index < Arr.Size THEN GetPtr := PCHAR(Arr.Data) + Index * Arr.ElementSize
        ELSE GetPtr := NIL;
END;

PROCEDURE Put(VAR Arr : TArray; Index : WORD; VAR Element);
BEGIN
        IF Index >= Arr.Size THEN EXIT;
        Move(Element
        , (PCHAR(Arr.Data) + Index * Arr.ElementSize)^
        , Arr.ElementSize);
END;

FUNCTION GetLength(VAR Arr : TArray) : WORD;
BEGIN
        GetLength := Arr.Size;
END;

PROCEDURE SetLength(VAR Arr : TArray; NewLength : WORD);
BEGIN
        IF Arr.Capacity < NewLength THEN ChangeCapacity(Arr, NewLength + ALLOC_STEP)
        ELSE IF Arr.Capacity > NewLength + ALLOC_STEP THEN ChangeCapacity(Arr, NewLength);
        Arr.Size := NewLength;
END;

PROCEDURE Copy(VAR SourceArr, DestArr : TArray);
BEGIN
        DestArr.ElementSize := SourceArr.ElementSize;
        SetLength(DestArr, SourceArr.Size);
        Move(PCHAR(SourceArr.Data)^
        , PCHAR(DestArr.Data)^
        , SourceArr.Size * SourceArr.ElementSize);
END;

PROCEDURE InsertAll(VAR SourceArr : TArray; SourceStartIndex, Count: WORD; VAR DestArr : TArray; DestStartIndex : WORD);
VAR     MoveCount: WORD;
BEGIN
        IF (SourceStartIndex + Count > SourceArr.Size) OR (Count = 0) THEN EXIT;
        IF DestStartIndex > DestArr.Size THEN EXIT;
        IF SourceArr.ElementSize <> DestArr.ElementSize THEN EXIT;
  
        MoveCount := DestArr.Size - DestStartIndex;
        SetLength(DestArr, DestArr.Size + Count);
  
        IF MoveCount > 0 THEN
                Move(PCHAR(DestArr.Data)[DestStartIndex * DestArr.ElementSize]
                , PCHAR(DestArr.Data)[(DestStartIndex + Count)* DestArr.ElementSize]
                , MoveCount * DestArr.ElementSize);
  
        Move(PCHAR(SourceArr.Data)[SourceStartIndex * SourceArr.ElementSize]
        , PCHAR(DestArr.Data)[DestStartIndex * DestArr.ElementSize]
        , Count * SourceArr.ElementSize);
        INC(DestArr.Size, Count);
END;

PROCEDURE Insert(VAR Arr : TArray; Index: WORD; VAR Element);
BEGIN
        IF Index > Arr.Size THEN EXIT;
        IF Arr.Size = Arr.Capacity THEN SetLength(Arr, Arr.Capacity + ALLOC_STEP);

        IF Index < Arr.Size THEN
                Move(PCHAR(Arr.Data)[Index * Arr.ElementSize]
                , PCHAR(Arr.Data)[(Index + 1) * Arr.ElementSize]
                , (Arr.Size - Index) * Arr.ElementSize);

        Move(Element, PCHAR(Arr.Data)[Index * Arr.ElementSize], Arr.ElementSize);
        INC(Arr.Size);
END;

PROCEDURE Swap(VAR Arr : TArray; Index1, Index2 : WORD);
VAR     Allocated  : BOOLEAN;
        TempBuffer : PCHAR;
        a1, a2     : PCHAR;
BEGIN
        IF (Index1 >= Arr.Size) OR (Index2 >= Arr.Size) THEN EXIT;

        Allocated := Arr.Capacity = Arr.Size;
        IF Allocated THEN GetMem(TempBuffer, Arr.ElementSize)
        ELSE TempBuffer := PCHAR(Arr.Data) + Arr.Size * Arr.ElementSize;

        a1 := PCHAR(Arr.Data) + Index1 * Arr.ElementSize;
        a2 := PCHAR(Arr.Data) + Index2 * Arr.ElementSize;

        Move(a1^, TempBuffer^, Arr.ElementSize);
        Move(a2^, a1^, Arr.ElementSize);
        Move(TempBuffer^, a2^, Arr.ElementSize);

        IF Allocated THEN FreeMem(TempBuffer, Arr.ElementSize) ELSE FillChar(TempBuffer^, Arr.ElementSize, #0);
END;

END.

