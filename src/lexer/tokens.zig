pub const EToken = enum {
    Integer,

    // Math
    Add,
    Sub,
    Mul,
    Div,
    Modulo,

    // Parentheses
    LParen,
    RParen,

    // Builtin features
    CmdPrintInt,
    CmdPrintChar,

    // End of statement
    EOS,

    // End of file
    EOF,

    // Variable stuff
    SayIdentifier,
    Assignment,
    VariableDeclaration,

    // Type stuff
    TypeDeclaration,

    // If syntax
    If,
    LBrace,
    RBrace,

    // Conditionals
    Equal,
    Less,
    Greater,
    NotEqual,

    // While loop
    While,
    Colon,

    // Pointers
    Ampersand,
    Dereference,
};
pub const TToken = struct { type: EToken, value: []const u8 };
