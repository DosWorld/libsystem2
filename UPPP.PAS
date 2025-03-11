{  MIT License

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
UNIT UPPP;

INTERFACE

TYPE
TGuessTable = ARRAY[0..4095] OF BYTE;

PROCEDURE Init(VAR GuessTable: TGuessTable; VAR Hash: WORD);

FUNCTION Compress(Source, Dest: PCHAR; Len: INTEGER; VAR GuessTable: TGuessTable; VAR Hash: WORD): INTEGER;
FUNCTION Decompress(Source, Dest: PCHAR; VAR Len: INTEGER; Final: BOOLEAN; VAR GuessTable: TGuessTable; VAR Hash: WORD): INTEGER;

PROCEDURE CompressFile(src_name, dst_name : STRING);
PROCEDURE DecompressFile(src_name, dst_name : STRING);

IMPLEMENTATION

USES SYSTEM2;

CONST
SIZ1 = 8192;

FUNCTION HashCode(Hash: WORD; X: BYTE) : WORD;
BEGIN
  Hash := (Hash SHL 4) XOR X;
  Hash := Hash AND 4095;
  HashCode := Hash;
END;

PROCEDURE Init(VAR GuessTable: TGuessTable; VAR Hash: WORD);
BEGIN
	Hash := 0;
	FillChar(GuessTable, SizeOf(TGuessTable), #0);
END;

FUNCTION Compress(Source, Dest: PCHAR; Len: INTEGER; VAR GuessTable: TGuessTable; VAR Hash: WORD): INTEGER;
VAR
  I, BitMask: INTEGER;
  FlagDest, OrgDest: PCHAR;
  Flags: BYTE;
BEGIN
  OrgDest := Dest;
  WHILE Len > 0 DO BEGIN
    FlagDest := Dest;
    INC(Dest);
    Flags := 0;
    BitMask := 1;
    FOR I := 0 TO 7 DO BEGIN
      IF Len = 0 THEN BREAK;
      IF GuessTable[Hash] = BYTE(Source^) THEN Flags := Flags OR BitMask
      ELSE BEGIN
        GuessTable[Hash] := BYTE(Source^);
        Dest^ := Source^;
        INC(Dest);
      END;
      Hash := HashCode(Hash, BYTE(Source^));
      INC(Source);
      BitMask := BitMask SHL 1;
      DEC(Len);
    END;
    FlagDest^ := CHR(Flags);
  END;
  Compress := Dest - OrgDest;
END;

FUNCTION Decompress(Source, Dest: PCHAR; VAR Len: INTEGER; Final: BOOLEAN; VAR GuessTable: TGuessTable; VAR Hash: WORD): INTEGER;
VAR
  I, BitMask: INTEGER;
  Flags: BYTE;
  OrgDest: PCHAR;
BEGIN
  OrgDest := Dest;
  WHILE Len >= 9 DO BEGIN
    Flags := BYTE(Source^);
    INC(Source);
    BitMask := 1;
    FOR I := 0 TO 7 DO BEGIN
      IF (Flags AND BitMask) <> 0 THEN Dest^ := CHR(GuessTable[Hash])
      ELSE BEGIN
        GuessTable[Hash] := BYTE(Source^);
        Dest^ := Source^;
        INC(Source);
        DEC(Len);
      END;
      Hash := HashCode(Hash, BYTE(Dest^));
      INC(Dest);
      BitMask := BitMask SHL 1;
    END;
    DEC(Len);
  END;
  WHILE Final AND (Len > 0) DO BEGIN
    Flags := BYTE(Source^);
    INC(Source);
    DEC(Len);
    BitMask := 1;
    FOR I := 0 TO 7 DO BEGIN
      IF (Flags AND BitMask) <> 0 THEN Dest^ := CHR(GuessTable[Hash])
      ELSE BEGIN
        IF Len = 0 THEN BREAK;
        GuessTable[Hash] := BYTE(Source^);
        Dest^ := Source^;
        INC(Source);
        DEC(Len);
      END;
      Hash := HashCode(Hash, BYTE(Dest^));
      INC(Dest);
      BitMask := BitMask SHL 1;
    END;
  END;
  Decompress := Dest - OrgDest;
END;

PROCEDURE CompressFile(src_name, dst_name : STRING);
VAR
  BufP: ARRAY[0..SIZ1-1] OF CHAR;
  BufC: ARRAY[0..(SIZ1 DIV 8 * 9) + 9] OF CHAR;
  GuessTable: TGuessTable;
  Hash: WORD;
  Len1, Len2: INTEGER;
  INF, OUTF : BFILE;
BEGIN
  Init(GuessTable, Hash);
  Assign(INF, src_name);
  Reset(INF, 1);
  Assign(OUTF, dst_name);
  ReWrite(OUTF, 1);
  WHILE NOT EOF(INF) DO BEGIN
    BlockRead(INF, BufP, SIZ1, Len1);
    Len2 := Compress(@BufP, @BufC, Len1, GuessTable, Hash);
    BlockWrite(OUTF, BufC, Len2);
  END;
  Close(INF);
  Close(OUTF);
END;

PROCEDURE DecompressFile(src_name, dst_name : STRING);
VAR
  BufP: ARRAY[0..SIZ1+9] OF CHAR;
  BufC: ARRAY[0..SIZ1*9+9] OF CHAR;
  GuessTable: TGuessTable;
  Hash: WORD;
  Len1, Len2, Len3: INTEGER;
  INF, OUTF : BFILE;
BEGIN
  Len1 := 0;
  Init(GuessTable, Hash);
  Assign(INF, src_name);
  Reset(INF, 1);
  Assign(OUTF, dst_name);
  ReWrite(OUTF, 1);
  WHILE NOT EOF(INF) DO BEGIN
    BlockRead(INF, BufP[Len1], SIZ1, Len3);
    INC(Len1, Len3);
    Len3 := Len1;
    Len2 := Decompress(@BufP, @BufC, Len1, FALSE, GuessTable, Hash);
    BlockWrite(OUTF, BufC, Len2);
    Move(BufP[Len3 - Len1], BufP, Len1);
  END;
  Len2 := Decompress(@BufP, @BufC, Len1, TRUE, GuessTable, Hash);
  BlockWrite(OUTF, BufC, Len2);
  Close(INF);
  Close(OUTF);
END;

END.
