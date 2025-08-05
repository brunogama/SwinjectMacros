#!/bin/bash
# Temporary fix for multi-line string issues
FILES=$(grep -r "error: insufficient indentation" . 2>&1 | grep -o '\./[^:]*\.swift' | sort -u)
echo "Files with multi-line string issues: $FILES"
