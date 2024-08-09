@echo off

del sequence.ppm
call touch sequence.ppm

call searches.exe sequence.ppm && x264-Encoder --fps 30 -o video.mp4 sequence.ppm
