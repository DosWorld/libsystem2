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
UNIT HashMap;

INTERFACE

CONST
TABLE_SIZE = 16;
MAX_KEY_LENGTH = 32;

TYPE
TMapKeyStr = STRING[MAX_KEY_LENGTH];
TMapKey = RECORD
    Key  : TMapKeyStr;
    Hash : WORD;
END;

PHashEntry = ^THashEntry;
THashEntry = RECORD
    Key   : TMapKey;
    Value : POINTER;
    Next  : PHashEntry;
END;

PHashMap = ^THashMap;
THashMap = RECORD
    Table       : ARRAY[0..TABLE_SIZE-1] OF PHashEntry;
    ElementSize : WORD;
END;

PROCEDURE Init(VAR Table: THashMap; ElementSize : WORD);
PROCEDURE Clear(VAR Table: THashMap);
FUNCTION ContainsKey(VAR Table: THashMap; Key: STRING): BOOLEAN;
FUNCTION Get(VAR Table: THashMap; Key: STRING; VAR Value): BOOLEAN;
FUNCTION GetPtr(VAR Table: THashMap; Key: STRING): POINTER;
PROCEDURE Put(VAR Table: THashMap; Key: STRING; VAR Value);
FUNCTION Remove(VAR Table: THashMap; Key: STRING): BOOLEAN;

IMPLEMENTATION

FUNCTION HashCode(VAR Key: TMapKeyStr): WORD;
VAR
  i: WORD;
  Hash: WORD;
BEGIN
  Hash := 0;
  FOR i := 1 TO Length(Key) DO INC(Hash, Hash * 48 + Ord(Key[i]));
  HashCode := Hash;
END;

FUNCTION TableIndex(Hash : WORD): INTEGER;
BEGIN
        TableIndex := Hash MOD TABLE_SIZE;
END;

FUNCTION CreateHashEntry(VAR Table: THashMap; Next : PHashEntry; VAR Key: TMapKey; VAR value): PHashEntry;
VAR
  P: PHashEntry;
BEGIN
  GetMem(P, SizeOf(THashEntry));
  P^.Key := Key;
  P^.Next := Next;
  GetMem(P^.Value, Table.ElementSize);
  Move(value, P^.Value^, Table.ElementSize);
  CreateHashEntry := P;
END;

PROCEDURE Init(VAR Table: THashMap; ElementSize : WORD);
BEGIN
  FillChar(Table, SizeOf(THashMap), 0);
  Table.ElementSize := ElementSize;
END;

PROCEDURE CreateKeys(VAR s : STRING; VAR k : TMapKey);
BEGIN
        k.Key := s;
        k.Hash := HashCode(k.Key);
END;

FUNCTION CompareKeys(VAR k1, k2 : TMapKey) : BOOLEAN;
BEGIN
        IF k1.Hash = k2.Hash THEN CompareKeys := k1.Key = k2.Key ELSE CompareKeys := FALSE;
END;

FUNCTION GetOrCreate(VAR Table: THashMap; Key: STRING; create : BOOLEAN) : PHashEntry;
VAR
  Entry: PHashEntry;
  newKey: TMapKey;
  tIndex : INTEGER;
BEGIN
  CreateKeys(Key, newKey);
  tIndex := TableIndex(newKey.Hash);
  Entry := Table.Table[tIndex];
  
  WHILE Entry <> NIL DO BEGIN
    IF CompareKeys(Entry^.Key, newKey) THEN BEGIN
      GetOrCreate := Entry;
      EXIT;
    END;
    Entry := Entry^.Next;
  END;
  IF create THEN BEGIN
          Entry := CreateHashEntry(Table, Table.Table[tIndex], newKey, newKey);
        Table.Table[tIndex] := Entry;
  END;
  GetOrCreate := Entry;
END;

FUNCTION Get(VAR Table: THashMap; Key: STRING; VAR Value): BOOLEAN;
VAR
  Entry: PHashEntry;
BEGIN
  Entry := GetOrCreate(Table, Key, FALSE);
  IF Entry <> NIL THEN Move(Entry^.Value^, Value, Table.ElementSize);
  Get := Entry <> NIL;
END;

FUNCTION GetPtr(VAR Table: THashMap; Key: STRING): POINTER;
VAR
  Entry: PHashEntry;
BEGIN
  Entry := GetOrCreate(Table, Key, FALSE);
  IF Entry <> NIL THEN GetPtr := Entry^.Value ELSE GetPtr := NIL;
END;

FUNCTION Remove(VAR Table: THashMap; Key: STRING): BOOLEAN;
VAR
  Entry, Prev: PHashEntry;
  newKey: TMapKey;
  tIndex : INTEGER;
BEGIN
  CreateKeys(Key, newKey);
  tIndex := TableIndex(newKey.Hash);
  Entry := Table.Table[tIndex];
  Prev := NIL;
 
  WHILE Entry <> NIL DO BEGIN
    IF CompareKeys(Entry^.Key, newKey) THEN BEGIN
      IF Prev = NIL THEN Table.Table[tIndex] := Entry^.Next
      ELSE Prev^.Next := Entry^.Next;
      FreeMem(Entry^.Value, Table.ElementSize);
      FreeMem(Entry, SizeOf(THashEntry));
      Remove := TRUE;
      EXIT;
    END;
    Prev := Entry;
    Entry := Entry^.Next;
  END;
  
  Remove := FALSE;
END;

PROCEDURE Clear(VAR Table: THashMap);
VAR
  i: WORD;
  Entry, Next: PHashEntry;
BEGIN
  FOR i := 0 TO TABLE_SIZE-1 DO BEGIN
    Entry := Table.Table[i];
    WHILE Entry <> NIL DO BEGIN
      Next := Entry^.Next;
      FreeMem(Entry^.Value, Table.ElementSize);
      FreeMem(Entry, SizeOf(THashEntry));
      Entry := Next;
    END;
  END;
  FillChar(Table, SizeOf(THashMap), 0);
END;

PROCEDURE Put(VAR Table: THashMap; Key: STRING; VAR Value);
VAR
  Entry : PHashEntry;
BEGIN
  Entry := GetOrCreate(Table, Key, TRUE);
  Move(Value, Entry^.Value^, Table.ElementSize);
END;

FUNCTION ContainsKey(VAR Table: THashMap; Key: STRING): BOOLEAN;
BEGIN
  ContainsKey := GetOrCreate(Table, Key, FALSE) <> NIL;
END;

END.
