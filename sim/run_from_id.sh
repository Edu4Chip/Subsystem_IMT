#!/bin/bash

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --id)
            ID="$2"
            shift 2
            ;;
        --file)
            FILE="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 --id ID --file FILENAME"
            exit 1
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$ID" ] || [ -z "$FILE" ]; then
    echo "Error: Both --id and --file arguments are required."
    exit 1
fi

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found."
    exit 1
fi

# Use grep to find the line with the given ID in the specified file
line=$(grep -m 1 "agent_core.*RQ.*id=$ID" "$FILE")

if [ -z "$line" ]; then
    echo "Error: No matching log line found for id=$ID in file '$FILE'"
    exit 1
fi

echo "Found log line: $line"

# Extract KEY, NONCE, AD, and DI using separate regex matches
# Initialize variables
KEY=""
NONCE=""
AD=""
DI=""

# Extract each field separately
if [[ $line =~ key=0x([0-9a-fA-F]+) ]]; then
    KEY=${BASH_REMATCH[1]}
fi

if [[ $line =~ nonce=0x([0-9a-fA-F]+) ]]; then
    NONCE=${BASH_REMATCH[1]}
fi

if [[ $line =~ ad=0x([0-9a-fA-F]+) ]]; then
    AD=${BASH_REMATCH[1]}
fi

if [[ $line =~ di=0x([0-9a-fA-F]+) ]]; then
    DI=${BASH_REMATCH[1]}
fi

# Check if all required fields were found
if [ -z "$KEY" ] || [ -z "$NONCE" ] || [ -z "$AD" ] || [ -z "$DI" ]; then
    echo "Error: Could not parse all required fields from the log line."
    echo "Found: KEY=$KEY, NONCE=$NONCE, AD=$AD, DI=$DI"
    exit 1
fi

# Print the extracted values for verification
echo "Extracted values:"
echo "  KEY=0x$KEY"
echo "  NONCE=0x$NONCE"
echo "  AD=0x$AD"
echo "  DI=0x$DI"

echo "Press [Enter] to continue..."
read -r

# Print the command for verification
echo "Running: KEY=$KEY NONCE=$NONCE AD=$AD DI=$DI ./run_single_enc.sh"

# Export variables and run the script
KEY=$KEY NONCE=$NONCE AD=$AD DI=$DI ./run_single_enc.sh
