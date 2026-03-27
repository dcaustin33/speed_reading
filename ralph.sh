#!/bin/bash

OUTPUT_DIR="output/claude_runs"
mkdir -p "$OUTPUT_DIR"

prompt_file="prompts/ralph.md"
filename=$(basename "$prompt_file" .md)

for i in {1..4}; do
    output_file="$OUTPUT_DIR/${filename}_run${i}_${timestamp}.txt"
    claude --dangerously-skip-permissions "Use the ralph skill if the usage skill says we are under 90% in the if hour window. You have all permissions so use the xcode simulator if needed." > "$output_file" 2>&1

done