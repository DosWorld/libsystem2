{$M 4096,0,0}
PROGRAM Rebuid;

USES DOS;

CONST
MAX = 256;
OPTIONS = '/m';

VAR
files   : ARRAY[1..MAX] OF STRING[12];
r       : SearchRec;
i, j, k : INTEGER;
tpc     : STRING;

BEGIN
        i := 0;
        FindFirst('*.pas', AnyFile, r);
        WHILE DOSError=0 DO BEGIN
                j := Pos('.', r.Name);
                IF j <> 0 THEN BEGIN
                        INC(i);
                        IF i>MAX THEN BEGIN
                                Writeln('Too many files.');
                                Halt(1);
                        END;
                        files[i] := Copy(r.name, 1, j-1);
                END;
                FindNext(R);
        END;
        tpc := FSearch('TPC.EXE', GetEnv('PATH'));
        IF Length(tpc) = 0 THEN BEGIN
                Writeln('tpc.exe not found.');
                Halt(1);
        END;
        FOR j := 1 TO i DO BEGIN
                Writeln(files[j]);
                SwapVectors;
                Exec(tpc, OPTIONS + ' ' + files[j]);
                SwapVectors;
                k := DOSExitCode;
                IF k <> 0 THEN BEGIN
                        Writeln('Error code: ', k);
                        Halt(k);
                END;
        END;
END.
