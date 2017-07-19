# AobSwap
linux script that scans a file for an array of bytes, and remplaces them with another given array of bytes

# Requirements

- Ruby
- colorize gem
- rasm2 (only if you need to disassemble before editing)

# Features

- Support for wildcards in the array of bytes to scan for, even nibbles are supported.
- Interactive mode that prompts the user before editing, with an option to disassemble the found memory region.
