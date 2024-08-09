@echo off

echo elastic circle collisions
call physics\elastic-circle-collisions\build.bat

echo numerical integration
call physics\numerical-integration\build.bat

echo searches
call searches\build.bat

echo fisher-yates
call shuffles\fisher-yates\build.bat

echo spanning tree
call spanning-tree\build.bat
