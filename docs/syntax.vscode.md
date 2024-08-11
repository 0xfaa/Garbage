# Creating a Syntax Highlighting Extension for 'garbage' Language in VS Code

## Prerequisites
1. Node.js and npm installed
2. Visual Studio Code installed
3. Basic knowledge of JSON and regular expressions

## Steps to Create the Extension

### 1. Set up the Extension Project
1. Open a terminal and create a new directory for your extension:
   ```
   mkdir garbage-lang
   cd garbage-lang
   ```
2. Initialize a new npm project:
   ```
   npm init -y
   ```
3. Install the vsce package globally (if not already installed):
   ```
   npm install -g vsce
   ```

### 2. Create the Extension Files
1. Create a `package.json` file with the following content:
   ```json
   {
     "name": "garbage-lang",
     "displayName": "Garbage Language Support",
     "description": "Syntax highlighting for Garbage language",
     "version": "0.0.1",
     "engines": {
       "vscode": "^1.60.0"
     },
     "categories": [
       "Programming Languages"
     ],
     "contributes": {
       "languages": [{
         "id": "garbage",
         "aliases": ["Garbage", "garbage"],
         "extensions": [".trash"],
         "configuration": "./language-configuration.json"
       }],
       "grammars": [{
         "language": "garbage",
         "scopeName": "source.garbage",
         "path": "./syntaxes/garbage.tmLanguage.json"
       }]
     }
   }
   ```

2. Create a `language-configuration.json` file:
   ```json
   {
     "comments": {
       "lineComment": "//"
     },
     "brackets": [
       ["{", "}"],
       ["[", "]"],
       ["(", ")"]
     ],
     "autoClosingPairs": [
       ["{", "}"],
       ["[", "]"],
       ["(", ")"],
       ["\"", "\""]
     ],
     "surroundingPairs": [
       ["{", "}"],
       ["[", "]"],
       ["(", ")"],
       ["\"", "\""]
     ]
   }
   ```

3. Create a `syntaxes` folder and add a `garbage.tmLanguage.json` file inside it:
   ```json
   {
     "name": "Garbage",
     "scopeName": "source.garbage",
     "patterns": [
       {
         "include": "#keywords"
       },
       {
         "include": "#strings"
       },
       {
         "include": "#comments"
       },
       {
         "include": "#numbers"
       },
       {
         "include": "#functions"
       }
     ],
     "repository": {
       "keywords": {
         "patterns": [{
           "name": "keyword.control.garbage",
           "match": "\\b(if|else|while|for|return|say)\\b"
         }]
       },
       "strings": {
         "name": "string.quoted.double.garbage",
         "begin": "\"",
         "end": "\"",
         "patterns": [
           {
             "name": "constant.character.escape.garbage",
             "match": "\\\\."
           }
         ]
       },
       "comments": {
         "name": "comment.line.double-slash.garbage",
         "match": "//.*$"
       },
       "numbers": {
         "name": "constant.numeric.garbage",
         "match": "\\b[0-9]+\\b"
       },
       "functions": {
         "patterns": [{
           "name": "support.function.garbage",
           "match": "@(socket_create|socket_bind|socket_listen|socket_accept|socket_read|socket_write|socket_close|print_int|print_char|print_buf)\\b"
         }]
       }
     }
   }
   ```

### 3. Test the Extension
1. Press `F5` in VS Code to launch a new Extension Development Host window.
2. Create a new file with a `.trash` extension and start writing some Garbage code.
3. Verify that the syntax highlighting is working as expected.

### 4. Package and Publish the Extension
1. Run the following command to package your extension:
   ```
   vsce package
   ```
2. This will create a `.vsix` file in your project directory.
3. To install the extension locally, go to VS Code, click on the Extensions view, click on the "..." at the top-right, and choose "Install from VSIX...".
4. Select the `.vsix` file you just created.

### 5. Publish to VS Code Marketplace (Optional)
1. Create an account on https://marketplace.visualstudio.com/
2. Get a Personal Access Token from Azure DevOps
3. Run `vsce login <publisher-name>` and enter your token
4. Run `vsce publish` to publish your extension

## Customization
- Adjust the `garbage.tmLanguage.json` file to match the specific syntax of your Garbage language.
- Add more patterns and scopes as needed for your language features.
- Update the file extensions in `package.json` if your Garbage files use different extensions.

Remember to update your extension regularly as you add new features to your Garbage language!