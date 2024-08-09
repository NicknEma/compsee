#!/bin/bash

code="$PWD"
opts=-g
cd debug > /dev/null
g++ $opts $code/src -o st.exe
cd $code > /dev/null
