#!/bin/bash

# Check if an input file was provided
if [ $# -eq 0 ]; then
    echo "Error: No input file provided"
    echo "Usage: $0 <path_to_assembly_file>"
    exit 1
fi

input_file="$1"
object_file="${input_file%.*}.o"
executable_file="${input_file%.*}"

# Assemble the file
echo "Assembling $input_file..."
as -g "$input_file" -o "$object_file"
if [ $? -ne 0 ]; then
    echo "Error: Assembly failed"
    exit 1
fi

# Get the SDK path
sdk_path=$(xcrun --sdk macosx --show-sdk-path)
if [ $? -ne 0 ]; then
    echo "Error: Failed to get SDK path"
    exit 1
fi

# Link the object file
echo "Linking $object_file..."
ld "$object_file" -o "$executable_file" -L"$sdk_path/usr/lib" -syslibroot -lSystem -e _main -arch arm64
if [ $? -ne 0 ]; then
    echo "Error: Linking failed"
    exit 1
fi

# Make the file executable
chmod +x "$executable_file"

echo "Successfully created executable: $executable_file"

# Clean up the object file (optional)
rm "$object_file"