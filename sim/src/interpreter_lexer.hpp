// Tokens and the lexer for the player's C++ subset.
// Internal to the interpreter: included only by interpreter.cpp.
#pragma once

#include "codefarm/interpreter.hpp"
#include "codefarm/world.hpp"

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

enum class TokenKind {
    End,
    Ident,
    KwWhile,
    KwIf,
    KwElse,
    KwTrue,
    KwFalse,
    LParen,
    RParen,
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    Semicolon,
    Comma,
    Colon,
    ColonColon,
    Dot,
    Number,
    String,
    KwInt,
    KwVoid,
    KwBool,
    KwDouble,
    KwReturn,
    KwUsing,
    KwNamespace,
    KwEnum,
    KwClass,
    KwFor,
    KwConst,
    KwConstexpr,
    KwStruct,
    KwSwitch,
    KwCase,
    KwDefault,
    KwBreak,
    KwContinue,
    KwAuto,
    Eq,
    EqEq,
    NotEq,
    Lt,
    Gt,
    Le,
    Ge,
    Plus,
    PlusPlus,
    PlusEq,
    Minus,
    MinusMinus,
    MinusEq,
    Star,
    StarEq,
    Slash,
    SlashEq,
    Percent,
    Amp,
    AmpAmp,
    PipePipe,
    Bang,
    Unknown,
};

struct Token {
    TokenKind kind = TokenKind::End;
    std::string text;
    int line = 1;
    int col = 1;
    int col_end = 1;
};

inline Token make_token(TokenKind kind, std::string text, int line, int col) {
    Token t;
    t.kind = kind;
    t.text = std::move(text);
    t.line = line;
    t.col = col;
    t.col_end = col + static_cast<int>(t.text.size());
    if (kind != TokenKind::End && t.col_end <= t.col) {
        t.col_end = t.col + 1;
    }
    return t;
}

inline SourceSpan span_of(const Token& tok) {
    SourceSpan s;
    s.line = tok.line;
    s.col_start = tok.col;
    s.col_end = tok.col_end > tok.col ? tok.col_end : tok.col + 1;
    return s;
}

inline SourceSpan span_after(const Token& tok) {
    SourceSpan s;
    s.line = tok.line;
    s.col_start = tok.col_end > 0 ? tok.col_end : tok.col;
    s.col_end = s.col_start + 1;
    return s;
}

inline std::string line_prefix(int line) {
    return "第 " + std::to_string(line) + " 行：";
}

class Lexer {
public:
    explicit Lexer(const std::string& source) : src_(source) {}

    Token next() {
        skip_trivia();
        if (pos_ >= src_.size()) {
            return make_token(TokenKind::End, "", line_, col_);
        }
        const int tline = line_;
        const int tcol = col_;
        const char c = src_[pos_];
        if (c == '"') {
            advance();
            std::string s;
            while (pos_ < src_.size() && src_[pos_] != '"') {
                if (src_[pos_] == '\\' && pos_ + 1 < src_.size()) {
                    advance();
                    const char e = src_[pos_];
                    if (e == 'n') s += '\n';
                    else if (e == 't') s += '\t';
                    else s += e;
                    advance();
                    continue;
                }
                s += src_[pos_];
                advance();
            }
            if (pos_ < src_.size()) advance();
            Token t = make_token(TokenKind::String, s, tline, tcol);
            t.col_end = col_;
            return t;
        }
        if (std::isalpha(static_cast<unsigned char>(c)) || c == '_') {
            const std::string ident = read_ident();
            TokenKind kind = TokenKind::Ident;
            if (ident == "while") kind = TokenKind::KwWhile;
            else if (ident == "if") kind = TokenKind::KwIf;
            else if (ident == "else") kind = TokenKind::KwElse;
            else if (ident == "true") kind = TokenKind::KwTrue;
            else if (ident == "false") kind = TokenKind::KwFalse;
            else if (ident == "int") kind = TokenKind::KwInt;
            else if (ident == "void") kind = TokenKind::KwVoid;
            else if (ident == "bool") kind = TokenKind::KwBool;
            else if (ident == "double") kind = TokenKind::KwDouble;
            else if (ident == "return") kind = TokenKind::KwReturn;
            else if (ident == "using") kind = TokenKind::KwUsing;
            else if (ident == "namespace") kind = TokenKind::KwNamespace;
            else if (ident == "enum") kind = TokenKind::KwEnum;
            else if (ident == "class") kind = TokenKind::KwClass;
            else if (ident == "for") kind = TokenKind::KwFor;
            else if (ident == "const") kind = TokenKind::KwConst;
            else if (ident == "constexpr") kind = TokenKind::KwConstexpr;
            else if (ident == "struct") kind = TokenKind::KwStruct;
            else if (ident == "switch") kind = TokenKind::KwSwitch;
            else if (ident == "case") kind = TokenKind::KwCase;
            else if (ident == "default") kind = TokenKind::KwDefault;
            else if (ident == "break") kind = TokenKind::KwBreak;
            else if (ident == "continue") kind = TokenKind::KwContinue;
            else if (ident == "auto") kind = TokenKind::KwAuto;
            else if (ident == "inline" || ident == "static" || ident == "virtual") {
                return next();  // ignored storage / inline specifiers
            }
            return make_token(kind, ident, tline, tcol);
        }
        if (std::isdigit(static_cast<unsigned char>(c))) {
            const std::string num = read_number();
            return make_token(TokenKind::Number, num, tline, tcol);
        }
        advance();
        auto two = [&](char want, TokenKind k2, const char* t2, TokenKind k1, const char* t1) {
            if (pos_ < src_.size() && src_[pos_] == want) {
                advance();
                return make_token(k2, t2, tline, tcol);
            }
            return make_token(k1, t1, tline, tcol);
        };
        switch (c) {
            case '(': return make_token(TokenKind::LParen, "(", tline, tcol);
            case ')': return make_token(TokenKind::RParen, ")", tline, tcol);
            case '{': return make_token(TokenKind::LBrace, "{", tline, tcol);
            case '}': return make_token(TokenKind::RBrace, "}", tline, tcol);
            case '[': return make_token(TokenKind::LBracket, "[", tline, tcol);
            case ']': return make_token(TokenKind::RBracket, "]", tline, tcol);
            case ';': return make_token(TokenKind::Semicolon, ";", tline, tcol);
            case ',': return make_token(TokenKind::Comma, ",", tline, tcol);
            case '.': return make_token(TokenKind::Dot, ".", tline, tcol);
            case ':':
                if (pos_ < src_.size() && src_[pos_] == ':') {
                    advance();
                    return make_token(TokenKind::ColonColon, "::", tline, tcol);
                }
                return make_token(TokenKind::Colon, ":", tline, tcol);
            case '=': return two('=', TokenKind::EqEq, "==", TokenKind::Eq, "=");
            case '<': return two('=', TokenKind::Le, "<=", TokenKind::Lt, "<");
            case '>': return two('=', TokenKind::Ge, ">=", TokenKind::Gt, ">");
            case '+':
                if (pos_ < src_.size() && src_[pos_] == '+') {
                    advance();
                    return make_token(TokenKind::PlusPlus, "++", tline, tcol);
                }
                return two('=', TokenKind::PlusEq, "+=", TokenKind::Plus, "+");
            case '-':
                if (pos_ < src_.size() && src_[pos_] == '-') {
                    advance();
                    return make_token(TokenKind::MinusMinus, "--", tline, tcol);
                }
                return two('=', TokenKind::MinusEq, "-=", TokenKind::Minus, "-");
            case '*': return two('=', TokenKind::StarEq, "*=", TokenKind::Star, "*");
            case '/': return two('=', TokenKind::SlashEq, "/=", TokenKind::Slash, "/");
            case '%': return make_token(TokenKind::Percent, "%", tline, tcol);
            case '&': return two('&', TokenKind::AmpAmp, "&&", TokenKind::Amp, "&");
            case '|':
                if (pos_ < src_.size() && src_[pos_] == '|') {
                    advance();
                    return make_token(TokenKind::PipePipe, "||", tline, tcol);
                }
                return make_token(TokenKind::Unknown, "|", tline, tcol);
            case '!': return two('=', TokenKind::NotEq, "!=", TokenKind::Bang, "!");
            default:
                return make_token(TokenKind::Unknown, std::string(1, c), tline, tcol);
        }
    }

private:
    void advance() {
        if (pos_ >= src_.size()) return;
        if (src_[pos_] == '\n') {
            line_++;
            col_ = 1;
        } else {
            col_++;
        }
        pos_++;
    }

    void skip_trivia() {
        while (pos_ < src_.size()) {
            const char c = src_[pos_];
            if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
                advance();
                continue;
            }
            if (c == '/' && pos_ + 1 < src_.size() && src_[pos_ + 1] == '/') {
                while (pos_ < src_.size() && src_[pos_] != '\n') advance();
                continue;
            }
            if (c == '/' && pos_ + 1 < src_.size() && src_[pos_ + 1] == '*') {
                advance();
                advance();
                while (pos_ + 1 < src_.size() && !(src_[pos_] == '*' && src_[pos_ + 1] == '/')) {
                    advance();
                }
                if (pos_ + 1 < src_.size()) {
                    advance();
                    advance();
                }
                continue;
            }
            if (c == '#') {
                while (pos_ < src_.size() && src_[pos_] != '\n') advance();
                continue;
            }
            break;
        }
    }

    std::string read_ident() {
        const std::size_t start = pos_;
        while (pos_ < src_.size()) {
            const char c = src_[pos_];
            if (std::isalnum(static_cast<unsigned char>(c)) || c == '_') advance();
            else break;
        }
        return src_.substr(start, pos_ - start);
    }

    std::string read_number() {
        const std::size_t start = pos_;
        while (pos_ < src_.size() && std::isdigit(static_cast<unsigned char>(src_[pos_]))) {
            advance();
        }
        if (pos_ < src_.size() && src_[pos_] == '.') {
            advance();
            while (pos_ < src_.size() && std::isdigit(static_cast<unsigned char>(src_[pos_]))) {
                advance();
            }
        }
        return src_.substr(start, pos_ - start);
    }

    const std::string& src_;
    std::size_t pos_ = 0;
    int line_ = 1;
    int col_ = 1;
};

}  // namespace codefarm::detail
