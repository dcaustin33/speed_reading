#!/bin/bash

OUTPUT_DIR="output/claude_runs"
mkdir -p "$OUTPUT_DIR"

prompt_file="prompts/ralph.md"
filename=$(basename "$prompt_file" .md)

for i in {7..11}; do
    timestamp=$(date +%Y%m%d_%H%M%S)
    output_file="$OUTPUT_DIR/${filename}_run${i}_${timestamp}.txt"

    echo "Running iteration $i: $prompt_file -> $output_file"
    cat "$prompt_file" | claude --permission-mode acceptEdits > "$output_file" 2>&1
    echo "Done: $output_file"

done