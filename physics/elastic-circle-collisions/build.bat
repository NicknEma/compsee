@echo off
del *.pdb > NUL 2> NUL
odin build . -out:elastic_circle_collisions.exe -debug -vet-shadowing -extra-linker-flags:"/opt:ref"
