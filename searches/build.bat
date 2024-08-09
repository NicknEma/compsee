@echo off

REM  -sanitize:address
odin build src -debug -o:none -out:searches.exe -vet -warnings-as-errors -extra-linker-flags:/map:searches_crt.map

REM odin build src -o:speed -out:searches.exe -no-crt -disable-assert -vet -warnings-as-errors -extra-linker-flags:/map:searches_no_crt.map
