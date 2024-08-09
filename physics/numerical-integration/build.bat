@echo off

set caller_location=%cd%
set script_location=%~dp0
cd %script_location%
set custom_root=%cd%
REM set custom_bin=%custom_root%\bin
cd %caller_location%

pushd %script_location%

del *.pdb > NUL 2> NUL
odin build . -debug -vet-shadowing -extra-linker-flags:"/opt:ref"

popd
