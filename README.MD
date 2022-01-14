# System2 library for Turbo Pascal (MS-DOS)

  This units is designed to replace some functions from system unit.

  It has support for:

  1. Long file names (LFN).
  2. Buffered I/O (DOS memory, 16K per file).
  3. Buffered I/O (EMS/XMS), up to 512 KB per file.
  4. File in memory (EMS/XMS) up to 4G each.
  5. Temporary files.
  6. Quoted command-line parameters.

  NOTE about 16K: This value became from EMS-page size,
  so please dont change it.

#  WinCB

  Unit for Windows Clipboard support for MS-DOS applications.
  64KB limited.

#  StrBin

  Convert Byte/Integers/Longint to/from string in various format.

# License

MIT License, See LICENSE file.
