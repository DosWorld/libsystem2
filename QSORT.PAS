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
UNIT QSort;

INTERFACE

{ ========================================================
  Compare function must return integer:

  FUNCTION(info : POINTER; element1, element2 : WORD) : INTEGER;

  IF element1 < element2 THEN return -1 (or any negative)
  IF element1 = element2 THEN return 0
  IF element1 > element2 THEN return +1 (or any positive)
  ======================================================== }

TYPE
QS_SWAP = PROCEDURE(info : POINTER; element1, element2 : WORD);
QS_CMP = FUNCTION(info : POINTER; element1, element2 : WORD) : INTEGER;

QS_SWAP_LONG = PROCEDURE(info : POINTER; element1, element2 : LONGINT);
QS_CMP_LONG = FUNCTION(info : POINTER; element1, element2 : LONGINT) : INTEGER;

PROCEDURE Sort(info : POINTER; left, right : WORD; cmp : QS_CMP; swap : QS_SWAP);
PROCEDURE SortLong(info : POINTER; left, right : LONGINT; cmp : QS_CMP_LONG; swap : QS_SWAP_LONG);

IMPLEMENTATION

PROCEDURE Sort(info : POINTER; left, right : WORD; cmp : QS_CMP; swap : QS_SWAP);
VAR     lower, upper, middle : WORD;
BEGIN
        lower := left;
        upper := right;
        middle:= ((right - left) shr 1) + left;
        REPEAT
                WHILE cmp(info, lower, middle) < 0 DO Inc(lower);
                WHILE cmp(info, middle, upper) < 0 DO Dec(upper);
                IF lower <= upper THEN BEGIN
                        Swap(info, lower, upper);
                        Inc(lower);
                        Dec(upper);
                END;
        UNTIL lower > upper;
        IF left < upper THEN Sort(info, left, upper, cmp, swap);
        IF lower < right THEN Sort(info, lower, right, cmp, swap);
END;

PROCEDURE SortLong(info : POINTER; left, right : LONGINT; cmp : QS_CMP_LONG; swap : QS_SWAP_LONG);
VAR     lower, upper, middle : LONGINT;
BEGIN
        lower := left;
        upper := right;
        middle:= ((right - left) shr 1) + left;
        REPEAT
                WHILE cmp(info, lower, middle) < 0 DO Inc(lower);
                WHILE cmp(info, middle, upper) < 0 DO Dec(upper);
                IF lower <= upper THEN BEGIN
                        Swap(info, lower, upper);
                        Inc(lower);
                        Dec(upper);
                END;
        UNTIL lower > upper;
        IF left < upper THEN SortLong(info, left, upper, cmp, swap);
        IF lower < right THEN SortLong(info, lower, right, cmp, swap);
END;

END.

