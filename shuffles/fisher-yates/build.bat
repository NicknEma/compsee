@echo off
del *.pdb > NUL 2> NUL
odin build . -out:fisher_yates.exe -debug -vet-shadowing -extra-linker-flags:"/opt:ref"
