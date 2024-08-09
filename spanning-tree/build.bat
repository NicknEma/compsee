@echo off

if not exist debug mkdir debug
odin build src -out:debug\st.exe -o:none -debug -vet-shadowing