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
{$A+,I-,S-,R-,D+,L+,Q-,F-,G-,O-,B-}
UNIT LZPMEM;

INTERFACE

FUNCTION LZP_encmem(input: PCHAR; len : WORD; output: PCHAR) : WORD;
FUNCTION LZP_decmem(input: PCHAR; len : WORD; output: PCHAR) : WORD;

IMPLEMENTATION

CONST
HASH_BITS = 12;
HASH_SIZE = (1 SHL HASH_BITS);
HASH_MASK = HASH_SIZE - 1;

TYPE
THashTable  = ARRAY[0..HASH_SIZE - 1] Of CHAR;

{
FUNCTION HashFunc(h: WORD; x: CHAR) : WORD;
BEGIN
        HashFunc := ((h * 160) XOR (ORD(x) AND $FF)) AND (HASH_SIZE - 1);
END;
}

FUNCTION HashFunc(h: WORD; x: CHAR) : WORD; ASSEMBLER;
ASM
        MOV  AX, [h]
        XOR  DX, DX
        MOV  CL, 160
        MUL  CL
        XOR  AL, [x]
        AND  AX, HASH_MASK
END;

FUNCTION LZP_encmem(input: PCHAR; len : WORD; output: PCHAR) : WORD;
VAR     hash, r, i : WORD;
        c          : CHAR;
        mask       : BYTE;
        HashTable  : THashTable;
        maskPtr    : PCHAR;
BEGIN
        FillChar(HashTable, SizeOf(THashTable), #0);
        hash := 0;
        r := ofs(output^);
        WHILE (len <> 0) DO BEGIN
                mask := 0;
                i := 0;
                maskPtr := output;
                INC(output);
                WHILE (i <= 7) AND (len <> 0) DO BEGIN
                        c := input^;
                        INC(input);
                        DEC(len);
                        IF c = HashTable[hash] THEN mask := mask OR (1 SHL i)
                        ELSE BEGIN
                                HashTable[hash] := c;
                                output^ := c;
                                INC(output);
                        END;
                        hash := HashFunc(hash, c);
                        INC(i);
                END;
                maskPtr^ := CHR(mask);
        END;
        LZP_encmem := ofs(output^) - r;
END;

FUNCTION LZP_decmem(input: PCHAR; len : WORD; output: PCHAR) : WORD;
VAR     hash, i, r : WORD;
        mask       : BYTE;
        c          : CHAR;
        HashTable  : THashTable;
BEGIN
        FillChar(HashTable, SizeOf(THashTable), #0);
        r := ofs(output^);
        hash := 0;
        WHILE (len <> 0) DO BEGIN
                mask := ORD(input^);
                INC(input);
                DEC(len);
                i := 0;
                WHILE (i <= 7) AND (len <> 0) DO BEGIN
                        IF (mask AND (1 SHL i)) <> 0 THEN c := HashTable[hash]
                        ELSE BEGIN
                                c := input^;
                                HashTable[hash] := c;
                                INC(input);
                                DEC(len);
                        END;
                        output^ := c;
                        INC(output);
                        hash := HashFunc(hash, c);
                        INC(i);
                END;
        END;
        LZP_decmem := ofs(output^) - r;
END;

END.
