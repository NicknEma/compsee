@echo off
del *.pdb > NUL 2> NUL
odin build . -out:integ.exe -debug -vet-shadowing -extra-linker-flags:"/opt:ref"
