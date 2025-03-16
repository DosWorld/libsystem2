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
{ Predictor Compression Protocol
  https://www.ietf.org/rfc/rfc1978.txt

 Predictor is a high speed compression algorithm, available without
 license fees.  The compression ratio obtained using predictor is not
 as good as other compression algorithms, but it remains one of the
 fastest algorithms available. }
{$A-,I-,S-,R-,D+,L+,Q-,F-,G-,O-,B-}
UNIT UPPP;

INTERFACE

CONST
PPP_BITS = 12;
PPP_HASH_TABLE = 1 SHL PPP_BITS;
PPP_HASH_TABLE_SIZE = PPP_HASH_TABLE - 1;

TYPE
PPP_HASH_TYPE = WORD;
PPP_TABLE = ARRAY [0..PPP_HASH_TABLE_SIZE] OF CHAR;

PROCEDURE Init(VAR GuessTable: PPP_TABLE; VAR Hash: PPP_HASH_TYPE);

FUNCTION Compress(Source, Dest: PCHAR; Len: INTEGER; VAR GuessTable: PPP_TABLE; VAR Hash: PPP_HASH_TYPE): INTEGER;
FUNCTION Decompress(Source, Dest: PCHAR; VAR Len: INTEGER; Final: BOOLEAN; VAR GuessTable: PPP_TABLE; VAR Hash: WORD): INTEGER;

PROCEDURE CompressFile(src_name, dst_name : STRING);
PROCEDURE DecompressFile(src_name, dst_name : STRING);

IMPLEMENTATION

USES SYSTEM2;

CONST
SIZ1 = 2048;

FUNCTION HashCode(Hash : WORD; x : BYTE) : PPP_HASH_TYPE;
BEGIN
        HashCode := ((Hash * 160) XOR (ORD(x))) AND PPP_HASH_TABLE_SIZE;
END;

PROCEDURE Init(VAR GuessTable: PPP_TABLE; VAR Hash: PPP_HASH_TYPE);
BEGIN
        Hash := 0;
        FillChar(GuessTable, SizeOf(PPP_TABLE), #0);
END;

FUNCTION Compress(Source, Dest: PCHAR; Len: INTEGER; VAR GuessTable: PPP_TABLE; VAR Hash: PPP_HASH_TYPE): INTEGER;
VAR
        I, BitMask        : INTEGER;
        FlagDest, OrgDest : PCHAR;
        Flags             : BYTE;
BEGIN
        OrgDest := Dest;
        WHILE Len > 0 DO BEGIN
                FlagDest := Dest;
                INC(Dest);
                Flags := 0;
                BitMask := 1;
                FOR I := 0 TO 7 DO BEGIN
                        IF Len = 0 THEN BREAK;
                        IF GuessTable[Hash] = Source^ THEN Flags := Flags OR BitMask
                        ELSE BEGIN
                                GuessTable[Hash] := Source^;
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

FUNCTION Decompress(Source, Dest: PCHAR; VAR Len: INTEGER; Final: BOOLEAN;
VAR GuessTable: PPP_TABLE; VAR Hash: PPP_HASH_TYPE): INTEGER;
VAR
        I, BitMask : INTEGER;
        Flags      : BYTE;
        OrgDest    : PCHAR;
BEGIN
        OrgDest := Dest;
        WHILE Len >= 9 DO BEGIN
                Flags := BYTE(Source^);
                INC(Source);
                BitMask := 1;
                FOR I := 0 TO 7 DO BEGIN
                        IF (Flags AND BitMask) <> 0 THEN Dest^ := GuessTable[Hash]
                        ELSE BEGIN
                                GuessTable[Hash] := Source^;
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
                        IF (Flags AND BitMask) <> 0 THEN Dest^ := GuessTable[Hash]
                        ELSE BEGIN
                        IF Len = 0 THEN BREAK;
                                GuessTable[Hash] := Source^;
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
CONST
OUTBUFSIZE = (SIZ1 DIV 8 * 9) + 9;
VAR
        BufP: ARRAY[0..SIZ1-1] OF CHAR;
        BufC: ARRAY[0..OUTBUFSIZE] OF CHAR;
        GuessTable: PPP_TABLE;
        Hash: PPP_HASH_TYPE;
        Len1, Len2: INTEGER;
        INF, OUTF : BFILE;
BEGIN
        Init(GuessTable, Hash);
        Assign(INF, src_name);
        Reset(INF);
        Assign(OUTF, dst_name);
        ReWrite(OUTF);
        WHILE NOT EOF(INF) DO BEGIN
                Len1 := BlockRead(INF, BufP, SIZ1);
                Len2 := Compress(@BufP, @BufC, Len1, GuessTable, Hash);
                BlockWrite(OUTF, BufC, Len2);
        END;
        Close(INF);
        Close(OUTF);
END;

PROCEDURE DecompressFile(src_name, dst_name : STRING);
CONST
OUTBUFSIZE = SIZ1*9+9;
VAR
        BufP: ARRAY[0..SIZ1+9] OF CHAR;
        BufC: ARRAY[0..OUTBUFSIZE] OF CHAR;
        GuessTable: PPP_TABLE;
        Hash: PPP_HASH_TYPE;
        Len1, Len2, Len3: INTEGER;
        INF, OUTF : BFILE;
BEGIN
        Len1 := 0;
        Init(GuessTable, Hash);
        Assign(INF, src_name);
        Reset(INF);
        Assign(OUTF, dst_name);
        ReWrite(OUTF);
        WHILE NOT EOF(INF) DO BEGIN
                Len3 := BlockRead(INF, BufP[Len1], SIZ1);
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
