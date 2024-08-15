# Garbage Compiler

<p align="center">
  <img src="https://github.com/user-attachments/assets/42b84dbc-1441-4d19-861e-395dfd0220c4"/>
  <img src="https://github.com/user-attachments/assets/42b84dbc-1441-4d19-861e-395dfd0220c4"/>
  <img src="https://github.com/user-attachments/assets/42b84dbc-1441-4d19-861e-395dfd0220c4"/>
  <img src="https://github.com/user-attachments/assets/42b84dbc-1441-4d19-861e-395dfd0220c4"/>
  <img src="https://github.com/user-attachments/assets/42b84dbc-1441-4d19-861e-395dfd0220c4"/>
</p>

Garbage is a low-level programming language compiler developed as a capstone project. It targets AArch64 assembly for MacOS on Apple Silicon (M1/M2/M3) processors.

## Features

- Compiles Garbage language to AArch64 assembly
- Supports direct assembly and linking
- Includes a run mode for immediate execution
- VSCode syntax highlighting extension available
- Assembly visualization tool ([VizWiz](https://vizwiz.netlify.app/)) for debugging

## Prerequisites

- MacOS with Apple Silicon (M1/M2/M3)
- Zig compiler (for building the compiler)

Note: The required assembler and linker typically come pre-installed on MacOS.

## Building the Compiler

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/garbage-compiler.git
   cd garbage-compiler
   ```

2. Build the compiler using Zig:
   ```
   zig build
   ```

## Usage

The Garbage compiler supports two modes: compile and run.

### Compile Mode

To compile a Garbage source file to assembly:

```
./garbage --compile path/to/your/source.trash
```

This will generate an assembly file (`source.asm`) and an executable in the same directory as the source file.

### Run Mode

To compile and immediately run a Garbage program:

```
./garbage --run path/to/your/source.trash
```

This will compile the source file, generate the executable, and run it, displaying the output.

## Example

Here's a simple "Hello, World!" program in Garbage:

```
// docs/hello_world.trash
say a: [14]u8 = "hello, world!\n"
@print_buf(a, 14)
```

To compile and run this program:

```
./garbage --run hello_world.trash
```

## Project Structure

```
src
├── ast
│   ├── node.zig
│   ├── parser.zig
│   └── program.zig
├── codegen
│   └── codegen.zig
├── compiler.zig
├── lexer
│   ├── lexer.zig
│   ├── test.zig
│   └── tokens.zig
├── main.zig
├── syntax_test.zig
└── test_ast.zig
```

- `main.zig`: The entry point of the compiler
- `compiler.zig`: Contains the core compilation logic
- `ast/`: Handles Abstract Syntax Tree (AST) generation and parsing
- `codegen/`: Generates AArch64 assembly from the AST
- `lexer/`: Handles lexical analysis and tokenization

## Tools

### VizWiz

VizWiz is an assembly visualization tool designed to aid in debugging Garbage programs. You can access it at [https://vizwiz.netlify.app](https://vizwiz.netlify.app).

### VSCode Extension

A syntax highlighting extension for Visual Studio Code is available to enhance the development experience with Garbage.

To install it just search for this: `vscode:extension/marketplace.visualstudio.com/items?itemName=0xfaa.garbage-syntax`

Or search for `garbage-syntax` in vscode extensions tab.

## Contributing

Contributions to the Garbage compiler are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## License

[MIT License](https://github.com/0xfaa/Garbage/blob/main/LICENSE)
