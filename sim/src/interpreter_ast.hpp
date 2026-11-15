// Syntax tree: expressions, statements, functions and structs.
// Internal to the interpreter: included only by interpreter.cpp.
#pragma once

#include "codefarm/interpreter.hpp"
#include "codefarm/world.hpp"
#include "interpreter_lexer.hpp"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace codefarm::detail {

enum class ExprKind {
    LiteralTrue,
    LiteralFalse,
    LiteralInt,
    LiteralReal,
    LiteralString,
    Ident,
    Call,
    Compare,
    Binary,
    Unary,
    Member,
    Index,
    Assign,
    InitList,
};

struct Expr {
    ExprKind kind = ExprKind::LiteralTrue;
    std::string name;
    std::string arg;
    std::string cmp_op;
    std::string cmp_rhs;
    std::string op;
    std::string text;
    int64_t int_val = 0;
    double real_val = 0;
    std::vector<Expr> kids;
    int line = 1;
    SourceSpan span;
};

enum class StmtKind {
    Block,
    ExprStmt,
    While,
    If,
    For,
    Return,
    VarDecl,
    Switch,
    Break,
    Continue,
};

struct Stmt {
    StmtKind kind = StmtKind::ExprStmt;
    int line = 1;
    SourceSpan span;
    Expr expr;
    std::vector<Stmt> body;
    std::vector<Stmt> else_body;
    std::string for_name;
    int for_start = 0;
    int for_end = 0;
    Expr for_end_expr;
    bool for_end_is_expr = false;
    std::string var_type;
    std::string var_name;
    bool var_const = false;
    bool var_ref = false;
    std::vector<int> array_dims;
    std::vector<Expr> array_dim_exprs;
    bool for_le = false;
    Expr for_start_expr;
    bool for_start_is_expr = false;
    Expr init;
    bool has_init = false;
    struct SwitchCase {
        std::vector<std::string> labels;  // empty label = default
        bool is_default = false;
        std::vector<Stmt> body;
    };
    std::vector<SwitchCase> cases;
};

struct FunctionParam {
    std::string type;
    std::string name;
    bool is_ref = false;
};

struct FunctionDef {
    std::string name;
    std::string ret;
    std::vector<FunctionParam> params;
    std::vector<Stmt> body;
    int line = 1;
};

struct StructDef {
    std::string name;
    std::vector<std::pair<std::string, std::string>> fields;
};

}  // namespace codefarm::detail
