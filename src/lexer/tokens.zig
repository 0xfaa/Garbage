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

    // Builtin primitives for debugging
    CmdPrintInt,
    CmdPrintChar,
    CmdPrintBuf,
    UnknownAtCommand,
    AtSign,

    // Networking primitives
    CmdSocketCreate,
    CmdSocketBind,
    CmdSocketListen,
    CmdSocketAccept,
    CmdSocketRead,
    CmdSocketWrite,
    CmdSocketClose,

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
    Less,
    Greater,
    Equal,
    NotEqual,
    GreaterEqual,
    LessEqual,
    Not,
    LogicalAnd,

    // While loop
    While,
    Colon,

    // Pointers
    Ampersand,
    Dereference,

    // Arrays
    LSquareBracket,
    RSquareBracket,
    Comma,

    // Strings
    StringLiteral,
};
pub const TToken = struct { type: EToken, value: []const u8 };
