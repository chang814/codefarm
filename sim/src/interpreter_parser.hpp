// Parser: turns tokens into the syntax tree and checks which language features are unlocked.
// Internal to the interpreter: included only by interpreter.cpp.
#pragma once

#include "codefarm/interpreter.hpp"
#include "codefarm/world.hpp"
#include "interpreter_ast.hpp"

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

class Parser {
public:
    Parser(const std::string& source, const World* world,
           const std::map<std::string, FunctionDef>* fns = nullptr,
           const std::map<std::string, StructDef>* structs = nullptr)
        : fns_(fns), structs_(structs), lexer_(source), world_(world), tok_(lexer_.next()) {}

    bool loops_unlocked() const { return world_ && world_->loops_unlocked(); }
    bool conditions_unlocked() const { return world_ && world_->conditions_unlocked(); }
    bool movement_unlocked() const { return world_ && world_->movement_unlocked(); }
    bool for_unlocked() const { return world_ && world_->for_unlocked(); }
    bool till_unlocked() const { return world_ && world_->till_unlocked(); }
    bool plant_unlocked() const { return world_ && world_->plant_unlocked(); }
    bool variables_unlocked() const { return world_ && world_->variables_unlocked(); }
    bool const_unlocked() const { return world_ && world_->const_unlocked(); }
    bool operators_unlocked() const { return world_ && world_->operators_unlocked(); }
    bool functions_unlocked() const { return world_ && world_->functions_unlocked(); }
    bool references_unlocked() const { return world_ && world_->references_unlocked(); }
    bool arrays_unlocked() const { return world_ && world_->arrays_unlocked(); }
    bool structs_unlocked() const { return world_ && world_->structs_unlocked(); }
    bool switch_unlocked() const { return world_ && world_->switch_unlocked(); }
    bool senses_unlocked() const { return world_ && world_->senses_unlocked(); }
    bool expand_unlocked() const { return world_ && world_->num_unlocked(UnlockId::Expand) > 0; }

    static bool is_builtin_type(const std::string& n) {
        static const char* kTypes[] = {"Dir", "Entity", "Ground", "Item", "Hat", "Cost", "Measure",
                                       "Companion", "Unlock", "Drone", "int64_t", "long", nullptr};
        for (int i = 0; kTypes[i]; ++i) {
            if (n == kTypes[i]) return true;
        }
        return false;
    }
    bool is_type_name(const std::string& n) const { return is_builtin_type(n) || structs.count(n) > 0; }

    std::vector<Stmt> main_body;
    std::map<std::string, FunctionDef> functions;
    std::map<std::string, StructDef> structs;
    std::vector<Stmt> globals;

    bool parse_program(std::string* error) {
        if (fns_) functions = *fns_;
        if (structs_) structs = *structs_;
        bool seen_main = false;
        while (tok_.kind != TokenKind::End) {
            if (tok_.kind == TokenKind::KwUsing) {
                if (!parse_using(error)) return false;
                continue;
            }
            if (tok_.kind == TokenKind::KwEnum) {
                if (!parse_enum(error)) return false;
                continue;
            }
            if (tok_.kind == TokenKind::KwStruct) {
                if (!parse_struct_def(error)) return false;
                continue;
            }
            if (tok_.kind == TokenKind::KwNamespace) {
                if (!parse_namespace_block(error)) return false;
                continue;
            }
            if (tok_.kind == TokenKind::KwConst || tok_.kind == TokenKind::KwConstexpr) {
                Stmt s;
                if (!parse_var_decl(&s, error, true)) return false;
                globals.push_back(std::move(s));
                continue;
            }
            if (tok_.kind == TokenKind::KwInt || tok_.kind == TokenKind::KwVoid ||
                tok_.kind == TokenKind::KwBool || tok_.kind == TokenKind::KwDouble ||
                (tok_.kind == TokenKind::Ident && is_type_name(tok_.text))) {
                // Lookahead: int main vs int foo vs int x =
                const Token type_tok = tok_;
                advance();
                bool is_ref = false;
                if (tok_.kind == TokenKind::Amp) {
                    is_ref = true;
                    advance();
                }
                if (tok_.kind != TokenKind::Ident) {
                    set_error(error, line_prefix(type_tok.line) + "类型后面需要名字。", current_span(),
                              ErrorKind::Generic);
                    return false;
                }
                const std::string name = tok_.text;
                const int name_line = tok_.line;
                advance();
                if (tok_.kind == TokenKind::LParen) {
                    if (name == "main") {
                        if (seen_main) {
                            set_error(error, line_prefix(name_line) + "程序里已经有一个 main 了。",
                                      current_span(), ErrorKind::Generic, "", "main");
                            return false;
                        }
                        if (is_ref) {
                            set_error(error, line_prefix(name_line) + "main 不能返回引用。", current_span(),
                                      ErrorKind::Generic);
                            return false;
                        }
                        if (!expect(TokenKind::LParen, error, name_line, "main 后面需要 '('。")) return false;
                        while (tok_.kind != TokenKind::RParen && tok_.kind != TokenKind::End) advance();
                        if (!expect(TokenKind::RParen, error, name_line, "main 的参数列表后面需要 ')'。")) return false;
                        if (!parse_block(&main_body, error)) return false;
                        seen_main = true;
                        continue;
                    }
                    if (!functions_unlocked()) {
                        set_error(error,
                                  line_prefix(name_line) +
                                      "自定义函数尚未解锁。到技能树花费胡萝卜即可在 main 外定义函数。",
                                  span_of(type_tok), ErrorKind::LockedSyntax, "到技能树解锁函数", "function");
                        return false;
                    }
                    FunctionDef fn;
                    fn.name = name;
                    fn.ret = type_tok.text;
                    fn.line = name_line;
                    if (!expect(TokenKind::LParen, error, name_line, "函数名后面需要 '('。")) return false;
                    while (tok_.kind != TokenKind::RParen && tok_.kind != TokenKind::End) {
                        FunctionParam p;
                        if (tok_.kind == TokenKind::KwInt || tok_.kind == TokenKind::KwBool ||
                            tok_.kind == TokenKind::KwVoid || tok_.kind == TokenKind::KwDouble ||
                            tok_.kind == TokenKind::Ident) {
                            p.type = tok_.text;
                            advance();
                        }
                        if (tok_.kind == TokenKind::Amp) {
                            if (!references_unlocked()) {
                                set_error(error,
                                          line_prefix(tok_.line) +
                                              "引用尚未解锁。到技能树花费胡萝卜即可使用 int&。",
                                          current_span(), ErrorKind::LockedSyntax, "到技能树解锁引用", "ref");
                                return false;
                            }
                            p.is_ref = true;
                            advance();
                        }
                        if (tok_.kind == TokenKind::Ident) {
                            p.name = tok_.text;
                            advance();
                        }
                        // Array parameters decay to a reference to the caller's array.
                        while (tok_.kind == TokenKind::LBracket) {
                            if (!arrays_unlocked()) {
                                set_error(error, line_prefix(tok_.line) + "数组尚未解锁。到技能树花费胡萝卜即可使用数组。",
                                          current_span(), ErrorKind::LockedSyntax, "到技能树解锁数组", "array");
                                return false;
                            }
                            while (tok_.kind != TokenKind::RBracket && tok_.kind != TokenKind::End) advance();
                            if (!expect(TokenKind::RBracket, error, name_line, "这里需要 ']'。")) return false;
                        }
                        fn.params.push_back(p);
                        if (tok_.kind == TokenKind::Comma) {
                            advance();
                            continue;
                        }
                        break;
                    }
                    if (!expect(TokenKind::RParen, error, name_line, "参数列表后面需要 ')'。")) return false;
                    if (!parse_block(&fn.body, error)) return false;
                    functions[fn.name] = std::move(fn);
                    continue;
                }
                // Variable at file scope: only const is allowed (already handled). Reject.
                set_error(error,
                          line_prefix(name_line) +
                              "可执行的语句只能写在 int main() 里。请把语句放进 main() 里。",
                          current_span(), ErrorKind::OutsideMain, "把语句放进 main() 里", "main");
                return false;
            }
            set_error(error,
                      line_prefix(tok_.line) +
                          "可执行的语句只能写在 int main() 里。请把语句放进 main() 里。",
                      current_span(), ErrorKind::OutsideMain, "把语句放进 main() 里", "main");
            return false;
        }
        if (!seen_main) {
            set_error(error,
                      "请把代码写在 int main() 里。例如：\n#include <bits/stdc++.h>\nusing namespace std;\n\nint main() {\n    harvest();\n    return 0;\n}",
                      SourceSpan{1, 1, 2}, ErrorKind::OutsideMain, "把语句放进 main() 里", "main");
            return false;
        }
        return true;
    }

    const Diagnostic& diagnostic() const { return diag_; }

private:
    Diagnostic diag_;
    Token prev_;
    std::vector<Token> open_stack_;
    const std::map<std::string, FunctionDef>* fns_ = nullptr;
    const std::map<std::string, StructDef>* structs_ = nullptr;

    SourceSpan current_span() const { return span_of(tok_); }

    void set_error(std::string* error, const std::string& message, SourceSpan span,
                   ErrorKind kind, const std::string& suggestion = {},
                   const std::string& code_word = {}) {
        if (error != nullptr) *error = message;
        diag_.message = message;
        diag_.span = span;
        diag_.kind = kind;
        diag_.suggestion = suggestion;
        diag_.code_word = code_word;
    }

    std::vector<std::string> unlocked_idents() const {
        std::vector<std::string> names = {"harvest", "do_a_flip"};
        if (conditions_unlocked()) names.emplace_back("can_harvest");
        if (movement_unlocked()) {
            names.emplace_back("move");
            names.emplace_back("East");
            names.emplace_back("West");
            names.emplace_back("North");
            names.emplace_back("South");
        }
        if (for_unlocked()) names.emplace_back("for");
        if (till_unlocked()) names.emplace_back("till");
        if (plant_unlocked()) {
            for (const char* n : {"plant", "get_entity_type", "get_ground_type", "Bush", "Grass",
                                  "None", "Soil", "Grassland"}) {
                names.emplace_back(n);
            }
        }
        if (loops_unlocked()) names.emplace_back("while");
        if (conditions_unlocked()) names.emplace_back("if");
        if (senses_unlocked()) {
            for (const char* n : {"get_pos_x", "get_pos_y", "num_items", "Hay", "Wood", "Carrot"}) {
                names.emplace_back(n);
            }
        }
        if (expand_unlocked()) names.emplace_back("get_world_size");
        if (world_ && world_->is_unlocked(UnlockId::Costs)) names.emplace_back("get_cost");
        if (world_ && world_->is_unlocked(UnlockId::Watering)) {
            names.emplace_back("use_item");
            names.emplace_back("get_water");
            names.emplace_back("Water");
        }
        if (world_ && world_->is_unlocked(UnlockId::Sunflowers)) names.emplace_back("measure");
        if (world_ && world_->is_unlocked(UnlockId::Mazes)) names.emplace_back("can_move");
        if (world_ && world_->is_unlocked(UnlockId::Cactus)) names.emplace_back("swap");
        if (world_ && world_->is_unlocked(UnlockId::Companions)) names.emplace_back("get_companion");
        if (world_ && world_->is_unlocked(UnlockId::Dinosaurs)) names.emplace_back("change_hat");
        if (world_ && world_->is_unlocked(UnlockId::Debug)) names.emplace_back("quick_print");
        if (world_ && world_->is_unlocked(UnlockId::Megafarm)) {
            names.emplace_back("spawn_drone");
            names.emplace_back("wait_for");
            names.emplace_back("has_finished");
        }
        if (functions_unlocked()) {
            for (const auto& kv : functions) names.push_back(kv.first);
        }
        return names;
    }

    bool is_builtin_name(const std::string& name) const {
        static const char* kAll[] = {
            "harvest", "do_a_flip", "can_harvest", "move", "till", "plant", "get_entity_type",
            "get_ground_type", "get_pos_x", "get_pos_y", "get_world_size", "num_items",
            "num_unlocked", "get_cost", "use_item", "get_water", "measure", "can_move", "swap",
            "get_companion", "change_hat", "clear", "unlock", "quick_print", "print", "print_slow",
            "get_time", "get_tick_count", "set_world_size", "set_execution_speed", "simulate",
            "random01", "spawn_drone", "wait_for", "has_finished", "num_drones", "max_drones",
            "min", "max", "abs", "std::min", "std::max", "std::abs", nullptr};
        for (int i = 0; kAll[i]; ++i) {
            if (name == kAll[i]) return true;
        }
        if (functions.count(name)) return true;
        return false;
    }

    bool parse_using(std::string* error) {
        const int line = tok_.line;
        advance();
        if (!expect(TokenKind::KwNamespace, error, line, "这里需要 namespace，例如 using namespace std;")) {
            return false;
        }
        if (tok_.kind != TokenKind::Ident) {
            set_error(error, line_prefix(line) + "using namespace 后面需要一个名字，例如 std。", current_span(), ErrorKind::Generic);
            return false;
        }
        advance();
        return expect(TokenKind::Semicolon, error, line, "语句末尾需要分号 ';'。");
    }

    bool parse_namespace_block(std::string* error) {
        const int line = tok_.line;
        if (!world_ || !world_->includes_unlocked()) {
            set_error(error, line_prefix(line) + "命名空间尚未解锁。到技能树解锁 #include 后即可使用 namespace。",
                      current_span(), ErrorKind::LockedSyntax, "到技能树解锁 include", "namespace");
            return false;
        }
        advance();
        if (tok_.kind == TokenKind::Ident) advance();
        if (!expect(TokenKind::LBrace, error, line, "namespace 后面需要 '{'。")) return false;
        // Parse declarations inside as if at file scope by recursively calling pieces.
        // For simplicity, skip until matching brace if empty or just allow function-like later;
        // we already consumed '{'. Parse inner using/enum/func by looping until '}'.
        while (tok_.kind != TokenKind::RBrace && tok_.kind != TokenKind::End) {
            set_error(error, line_prefix(tok_.line) + "暂时请把函数写在命名空间外，或使用 #include 自己的头文件。",
                      current_span(), ErrorKind::Generic);
            return false;
        }
        return expect(TokenKind::RBrace, error, line, "缺少与 '{' 匹配的 '}'。");
    }

    bool parse_enum(std::string* error) {
        const int line = tok_.line;
        advance();
        if (tok_.kind == TokenKind::KwClass) advance();
        if (tok_.kind == TokenKind::Ident) advance();
        if (tok_.kind == TokenKind::Colon) {
            advance();
            if (tok_.kind == TokenKind::KwInt || tok_.kind == TokenKind::Ident) advance();
        }
        if (!expect(TokenKind::LBrace, error, line, "enum 后面需要 '{'。")) return false;
        while (tok_.kind != TokenKind::RBrace && tok_.kind != TokenKind::End) {
            if (tok_.kind == TokenKind::Ident || tok_.kind == TokenKind::Comma) {
                advance();
            } else {
                set_error(error, line_prefix(tok_.line) + "enum 里只能写枚举名，并用逗号分隔。", current_span(), ErrorKind::Generic);
                return false;
            }
        }
        if (!expect(TokenKind::RBrace, error, line, "缺少与 '{' 匹配的 '}'。")) return false;
        return expect(TokenKind::Semicolon, error, line, "enum 声明末尾需要分号 ';'。");
    }

    bool parse_struct_def(std::string* error) {
        const int line = tok_.line;
        if (!structs_unlocked()) {
            set_error(error, line_prefix(line) + "结构体尚未解锁。到技能树花费胡萝卜即可定义 struct。",
                      current_span(), ErrorKind::LockedSyntax, "到技能树解锁结构体", "struct");
            return false;
        }
        advance();
        if (tok_.kind != TokenKind::Ident) {
            set_error(error, line_prefix(line) + "struct 后面需要类型名。", current_span(), ErrorKind::Generic);
            return false;
        }
        StructDef def;
        def.name = tok_.text;
        advance();
        if (!expect(TokenKind::LBrace, error, line, "struct 后面需要 '{'。")) return false;
        while (tok_.kind != TokenKind::RBrace && tok_.kind != TokenKind::End) {
            std::string ty;
            if (tok_.kind == TokenKind::KwInt || tok_.kind == TokenKind::KwBool ||
                tok_.kind == TokenKind::KwDouble || tok_.kind == TokenKind::Ident) {
                ty = tok_.text;
                advance();
            } else {
                set_error(error, line_prefix(tok_.line) + "结构体成员需要类型。", current_span(), ErrorKind::Generic);
                return false;
            }
            if (tok_.kind != TokenKind::Ident) {
                set_error(error, line_prefix(tok_.line) + "结构体成员需要名字。", current_span(), ErrorKind::Generic);
                return false;
            }
            def.fields.emplace_back(ty, tok_.text);
            advance();
            if (!expect(TokenKind::Semicolon, error, line, "成员末尾需要分号 ';'。")) return false;
        }
        if (!expect(TokenKind::RBrace, error, line, "缺少与 '{' 匹配的 '}'。")) return false;
        if (!expect(TokenKind::Semicolon, error, line, "struct 声明末尾需要分号 ';'。")) return false;
        structs[def.name] = def;
        return true;
    }

    bool parse_return(Stmt* out, std::string* error) {
        const int line = tok_.line;
        advance();
        if (tok_.kind != TokenKind::Semicolon) {
            if (!parse_expr(&out->expr, error)) return false;
            out->has_init = true;
        }
        if (!expect(TokenKind::Semicolon, error, line, "return 末尾需要分号 ';'。")) return false;
        out->kind = StmtKind::Return;
        out->line = line;
        out->span.line = line;
        out->span.col_start = 1;
        out->span.col_end = 7;
        return true;
    }

    bool parse_statement(Stmt* out, std::string* error) {
        if (tok_.kind == TokenKind::KwWhile) return parse_while(out, error);
        if (tok_.kind == TokenKind::KwFor) return parse_for(out, error);
        if (tok_.kind == TokenKind::KwIf) return parse_if(out, error);
        if (tok_.kind == TokenKind::KwReturn) return parse_return(out, error);
        if (tok_.kind == TokenKind::KwSwitch) return parse_switch(out, error);
        if (tok_.kind == TokenKind::KwBreak) {
            out->kind = StmtKind::Break;
            out->line = tok_.line;
            advance();
            return expect(TokenKind::Semicolon, error, out->line, "break 末尾需要分号 ';'。");
        }
        if (tok_.kind == TokenKind::KwContinue) {
            out->kind = StmtKind::Continue;
            out->line = tok_.line;
            advance();
            return expect(TokenKind::Semicolon, error, out->line, "continue 末尾需要分号 ';'。");
        }
        if (tok_.kind == TokenKind::KwConst || tok_.kind == TokenKind::KwConstexpr ||
            tok_.kind == TokenKind::KwInt || tok_.kind == TokenKind::KwBool ||
            tok_.kind == TokenKind::KwDouble || tok_.kind == TokenKind::KwAuto ||
            (tok_.kind == TokenKind::Ident && is_type_name(tok_.text))) {
            const bool is_const = tok_.kind == TokenKind::KwConst || tok_.kind == TokenKind::KwConstexpr;
            return parse_var_decl(out, error, is_const);
        }
        return parse_expr_stmt(out, error);
    }

    bool parse_var_decl(Stmt* out, std::string* error, bool is_const) {
        const int line = tok_.line;
        if (is_const) {
            if (!const_unlocked() && !variables_unlocked()) {
                // const node is the intended unlock, but variables also enable typed decls
            }
            if (!const_unlocked()) {
                set_error(error, line_prefix(line) + "const 尚未解锁。到技能树花费木头或干草即可使用 const int。",
                          current_span(), ErrorKind::LockedSyntax, "到技能树解锁 const", "const");
                return false;
            }
            advance();
        }
        if (!is_const && !variables_unlocked() && !const_unlocked()) {
            set_error(error, line_prefix(line) + "变量尚未解锁。到技能树花费干草或木头即可使用 int / bool。",
                      current_span(), ErrorKind::LockedSyntax, "到技能树解锁变量", "int");
            return false;
        }
        if (!is_const && !variables_unlocked()) {
            set_error(error, line_prefix(line) + "变量尚未解锁。到技能树花费干草或木头即可使用 int / bool。",
                      current_span(), ErrorKind::LockedSyntax, "到技能树解锁变量", "int");
            return false;
        }
        if (tok_.kind != TokenKind::KwInt && tok_.kind != TokenKind::KwBool &&
            tok_.kind != TokenKind::KwDouble && tok_.kind != TokenKind::KwAuto &&
            tok_.kind != TokenKind::Ident) {
            set_error(error, line_prefix(line) + "声明需要类型，例如 int 或 bool。", current_span(), ErrorKind::Generic);
            return false;
        }
        out->var_type = tok_.text;
        advance();
        if (tok_.kind == TokenKind::Amp) {
            if (!references_unlocked()) {
                set_error(error, line_prefix(line) + "引用尚未解锁。到技能树花费胡萝卜即可使用 int&。",
                          current_span(), ErrorKind::LockedSyntax, "到技能树解锁引用", "ref");
                return false;
            }
            out->var_ref = true;
            advance();
        }
        if (tok_.kind != TokenKind::Ident) {
            set_error(error, line_prefix(line) + "声明需要变量名。", current_span(), ErrorKind::Generic);
            return false;
        }
        out->var_name = tok_.text;
        advance();
        while (tok_.kind == TokenKind::LBracket) {
            if (!arrays_unlocked()) {
                set_error(error, line_prefix(line) + "数组尚未解锁。到技能树花费胡萝卜即可使用数组或 std::vector。",
                          current_span(), ErrorKind::LockedSyntax, "到技能树解锁数组", "array");
                return false;
            }
            advance();
            Expr dim;
            if (!parse_expr(&dim, error)) return false;
            out->array_dim_exprs.push_back(std::move(dim));
            out->array_dims.push_back(0);
            if (!expect(TokenKind::RBracket, error, line, "这里需要 ']'。")) return false;
        }
        if (tok_.kind == TokenKind::Eq) {
            advance();
            if (tok_.kind == TokenKind::LBrace) {
                if (!parse_init_list(&out->init, error)) return false;
            } else if (!parse_expr(&out->init, error)) {
                return false;
            }
            out->has_init = true;
        } else if (tok_.kind == TokenKind::LBrace && !out->array_dims.empty()) {
            if (!parse_init_list(&out->init, error)) return false;
            out->has_init = true;
        }
        if (!expect(TokenKind::Semicolon, error, line, "声明末尾需要分号 ';'。")) return false;
        out->kind = StmtKind::VarDecl;
        out->line = line;
        out->var_const = is_const;
        return true;
    }

    bool parse_init_list(Expr* out, std::string* error) {
        const int line = tok_.line;
        out->kind = ExprKind::InitList;
        out->line = line;
        out->span = current_span();
        if (!expect(TokenKind::LBrace, error, line, "需要 '{'。")) return false;
        while (tok_.kind != TokenKind::RBrace && tok_.kind != TokenKind::End) {
            Expr item;
            if (tok_.kind == TokenKind::LBrace) {
                if (!parse_init_list(&item, error)) return false;
            } else if (!parse_expr(&item, error)) {
                return false;
            }
            out->kids.push_back(std::move(item));
            if (tok_.kind != TokenKind::Comma) break;
            advance();
        }
        return expect(TokenKind::RBrace, error, line, "缺少与 '{' 匹配的 '}'。");
    }

    bool parse_switch(Stmt* out, std::string* error) {
        const int line = tok_.line;
        if (!switch_unlocked()) {
            set_error(error, line_prefix(line) + "switch 尚未解锁。到技能树花费胡萝卜即可使用 switch。",
                      current_span(), ErrorKind::LockedSyntax, "到技能树解锁 switch", "switch");
            return false;
        }
        advance();
        if (!expect(TokenKind::LParen, error, line, "switch 后面需要 '('。")) return false;
        if (!parse_expr(&out->expr, error)) return false;
        if (!expect(TokenKind::RParen, error, line, "条件后面需要 ')'。")) return false;
        if (!expect(TokenKind::LBrace, error, line, "switch 后面需要 '{'。")) return false;
        while (tok_.kind != TokenKind::RBrace && tok_.kind != TokenKind::End) {
            Stmt::SwitchCase c;
            if (tok_.kind == TokenKind::KwDefault) {
                c.is_default = true;
                advance();
                if (!expect(TokenKind::Colon, error, line, "default 后面需要 ':'。")) return false;
            } else if (tok_.kind == TokenKind::KwCase) {
                advance();
                if (tok_.kind == TokenKind::Ident || tok_.kind == TokenKind::Number ||
                    tok_.kind == TokenKind::KwTrue || tok_.kind == TokenKind::KwFalse) {
                    c.labels.push_back(tok_.text);
                    advance();
                }
                // Dir::East
                if (tok_.kind == TokenKind::ColonColon) {
                    advance();
                    if (tok_.kind == TokenKind::Ident) {
                        c.labels.back() = tok_.text;
                        advance();
                    }
                }
                if (!expect(TokenKind::Colon, error, line, "case 后面需要 ':'。")) return false;
            } else {
                set_error(error, line_prefix(tok_.line) + "switch 里需要 case 或 default。", current_span(),
                          ErrorKind::Generic);
                return false;
            }
            while (tok_.kind != TokenKind::KwCase && tok_.kind != TokenKind::KwDefault &&
                   tok_.kind != TokenKind::RBrace && tok_.kind != TokenKind::End) {
                Stmt st;
                if (!parse_statement(&st, error)) return false;
                c.body.push_back(std::move(st));
            }
            out->cases.push_back(std::move(c));
        }
        if (!expect(TokenKind::RBrace, error, line, "缺少与 '{' 匹配的 '}'。")) return false;
        for (std::size_t ci = 0; ci + 1 < out->cases.size(); ++ci) {
            auto& c = out->cases[ci];
            if (c.body.empty()) {
                auto& nx = out->cases[ci + 1];
                nx.labels.insert(nx.labels.end(), c.labels.begin(), c.labels.end());
                if (c.is_default) nx.is_default = true;
            }
        }
        out->kind = StmtKind::Switch;
        out->line = line;
        return true;
    }

    bool parse_while(Stmt* out, std::string* error) {
        const int line = tok_.line;
        if (!loops_unlocked()) {
            set_error(error, line_prefix(line) + "循环尚未解锁。到技能树花 5 个干草即可使用 while。",
                      current_span(), ErrorKind::LockedSyntax, "到技能树花 5 个干草解锁", "while");
            return false;
        }
        advance();
        if (!expect(TokenKind::LParen, error, line, "while 后面需要 '('。")) return false;
        Expr cond;
        if (!parse_expr(&cond, error)) return false;
        if (!expect(TokenKind::RParen, error, cond.line, "条件后面需要 ')'。")) return false;
        std::vector<Stmt> body;
        if (!parse_block_or_single(&body, error, line, "while")) return false;
        out->kind = StmtKind::While;
        out->line = line;
        out->span = cond.span;
        out->span.line = line;
        out->expr = std::move(cond);
        out->body = std::move(body);
        return true;
    }

    bool parse_for(Stmt* out, std::string* error) {
        const int line = tok_.line;
        if (!for_unlocked()) {
            set_error(error,
                      line_prefix(line) +
                          "for 循环尚未解锁。到技能树花 30 个干草即可使用 for (int i = 0; i < 3; i++)。",
                      current_span(), ErrorKind::LockedSyntax, "到技能树花 30 个干草解锁", "for");
            return false;
        }
        advance();
        if (!expect(TokenKind::LParen, error, line, "for 后面需要 '('。")) return false;
        if (tok_.kind != TokenKind::KwInt) {
            set_error(error, line_prefix(line) + "第一期请写成 for (int i = 0; i < 3; i++)。", current_span(), ErrorKind::Generic);
            return false;
        }
        advance();
        if (tok_.kind != TokenKind::Ident) {
            set_error(error, line_prefix(line) + "for 需要循环变量名，例如 i。", current_span(), ErrorKind::Generic);
            return false;
        }
        out->for_name = tok_.text;
        advance();
        if (!expect(TokenKind::Eq, error, line, "for 里需要 '=', 例如 for (int i = 0; ...)。")) return false;
        if (tok_.kind == TokenKind::Number) {
            out->for_start = std::stoi(tok_.text);
            advance();
        } else if (variables_unlocked() || const_unlocked()) {
            Expr init;
            if (!parse_expr(&init, error)) return false;
            if (init.kind == ExprKind::LiteralInt) {
                out->for_start = static_cast<int>(init.int_val);
            } else {
                out->for_start_expr = std::move(init);
                out->for_start_is_expr = true;
            }
        } else {
            set_error(error, line_prefix(line) + "第一期请写成 for (int i = 0; i < 3; i++)。", current_span(), ErrorKind::Generic);
            return false;
        }
        if (!expect(TokenKind::Semicolon, error, line, "for 的三段之间需要分号 ';'。")) return false;
        // condition: name < expr
        if (tok_.kind == TokenKind::Ident && tok_.text == out->for_name) {
            advance();
            if (tok_.kind != TokenKind::Lt && tok_.kind != TokenKind::Le) {
                set_error(error, line_prefix(line) + "请写成 i < n 的计数循环。", current_span(), ErrorKind::Generic);
                return false;
            }
            const bool le = tok_.kind == TokenKind::Le;
            advance();
            Expr end;
            if (tok_.kind == TokenKind::Number) {
                out->for_end = std::stoi(tok_.text);
                if (le) out->for_end += 1;
                advance();
            } else {
                if (!parse_expr(&end, error)) return false;
                out->for_end_expr = std::move(end);
                out->for_end_is_expr = true;
                out->for_le = le;
            }
        } else {
            set_error(error, line_prefix(line) + "请写成 for (int i = 0; i < n; i++)。", current_span(), ErrorKind::Generic);
            return false;
        }
        if (!expect(TokenKind::Semicolon, error, line, "for 的三段之间需要分号 ';'。")) return false;
        // increment: i++ or ++i or i += 1
        if (tok_.kind == TokenKind::PlusPlus) {
            advance();
            if (tok_.kind == TokenKind::Ident) advance();
        } else if (tok_.kind == TokenKind::Ident) {
            advance();
            if (tok_.kind == TokenKind::PlusPlus) advance();
            else if (tok_.kind == TokenKind::PlusEq) {
                advance();
                if (tok_.kind == TokenKind::Number) advance();
                else {
                    Expr dummy;
                    if (!parse_expr(&dummy, error)) return false;
                }
            } else {
                set_error(error, line_prefix(line) + "请写成 i++。", current_span(), ErrorKind::Generic);
                return false;
            }
        } else {
            set_error(error, line_prefix(line) + "请写成 i++。", current_span(), ErrorKind::Generic);
            return false;
        }
        if (!expect(TokenKind::RParen, error, line, "for 的括号后面需要 ')'。")) return false;
        std::vector<Stmt> body;
        if (!parse_block_or_single(&body, error, line, "for")) return false;
        out->kind = StmtKind::For;
        out->line = line;
        out->span.line = line;
        out->body = std::move(body);
        return true;
    }

    bool parse_if(Stmt* out, std::string* error) {
        const int line = tok_.line;
        if (!conditions_unlocked()) {
            set_error(error,
                      line_prefix(line) +
                          "条件判断尚未解锁。到技能树花 12 个干草即可使用 if 和 can_harvest()。",
                      current_span(), ErrorKind::LockedSyntax, "到技能树花 12 个干草解锁", "if");
            return false;
        }
        advance();
        if (!expect(TokenKind::LParen, error, line, "if 后面需要 '('。")) return false;
        Expr cond;
        if (!parse_expr(&cond, error)) return false;
        if (!expect(TokenKind::RParen, error, cond.line, "条件后面需要 ')'。")) return false;
        std::vector<Stmt> body;
        if (!parse_block_or_single(&body, error, line, "if")) return false;
        std::vector<Stmt> else_body;
        if (tok_.kind == TokenKind::KwElse) {
            advance();
            if (!parse_block_or_single(&else_body, error, line, "else")) return false;
        }
        out->kind = StmtKind::If;
        out->line = line;
        out->span = cond.span;
        out->span.line = line;
        out->expr = std::move(cond);
        out->body = std::move(body);
        out->else_body = std::move(else_body);
        return true;
    }

    bool parse_block_or_single(std::vector<Stmt>* body, std::string* error, int line, const char* keyword) {
        if (tok_.kind == TokenKind::LBrace) return parse_block(body, error);
        if (tok_.kind == TokenKind::End || tok_.kind == TokenKind::RBrace) {
            set_error(error, line_prefix(line) + std::string(keyword) + " 后面缺少语句。", current_span(), ErrorKind::Generic);
            return false;
        }
        Stmt stmt;
        if (!parse_statement(&stmt, error)) return false;
        body->push_back(std::move(stmt));
        return true;
    }

    bool parse_block(std::vector<Stmt>* body, std::string* error) {
        const int line = tok_.line;
        if (!expect(TokenKind::LBrace, error, line, "需要 '{'。")) return false;
        while (tok_.kind != TokenKind::RBrace && tok_.kind != TokenKind::End) {
            Stmt stmt;
            if (!parse_statement(&stmt, error)) return false;
            body->push_back(std::move(stmt));
        }
        if (!expect(TokenKind::RBrace, error, line, "缺少与 '{' 匹配的 '}'。")) return false;
        return true;
    }

    bool parse_expr_stmt(Stmt* out, std::string* error) {
        Expr expr;
        if (!parse_expr(&expr, error)) return false;
        if (!expect(TokenKind::Semicolon, error, expr.line, "语句末尾需要分号 ';'。")) return false;
        out->kind = StmtKind::ExprStmt;
        out->line = expr.line;
        out->span = expr.span;
        out->expr = std::move(expr);
        return true;
    }

    bool parse_expr(Expr* out, std::string* error) { return parse_assignment(out, error); }

    bool parse_assignment(Expr* out, std::string* error) {
        if (!parse_or(out, error)) return false;
        if (tok_.kind == TokenKind::Eq || tok_.kind == TokenKind::PlusEq ||
            tok_.kind == TokenKind::MinusEq || tok_.kind == TokenKind::StarEq ||
            tok_.kind == TokenKind::SlashEq) {
            if (!variables_unlocked()) {
                set_error(error, line_prefix(tok_.line) + "赋值尚未解锁。到技能树解锁变量后即可使用。",
                          current_span(), ErrorKind::LockedSyntax, "到技能树解锁变量", "=");
                return false;
            }
            Expr rhs;
            const std::string op = tok_.text;
            advance();
            if (!parse_assignment(&rhs, error)) return false;
            Expr as;
            as.kind = ExprKind::Assign;
            as.op = op;
            as.line = out->line;
            as.span = out->span;
            as.kids.push_back(*out);
            as.kids.push_back(std::move(rhs));
            *out = std::move(as);
        }
        return true;
    }

    bool parse_binary(Expr* out, std::string* error, int prec) {
        // unused helper placeholder
        (void)out; (void)error; (void)prec;
        return true;
    }

    bool parse_or(Expr* out, std::string* error) {
        if (!parse_and(out, error)) return false;
        while (tok_.kind == TokenKind::PipePipe) {
            if (!require_ops(error, tok_.line, "||")) return false;
            Expr rhs;
            const std::string op = tok_.text;
            const int line = out->line;
            advance();
            if (!parse_and(&rhs, error)) return false;
            *out = make_binary(ExprKind::Binary, op, *out, rhs, line);
        }
        return true;
    }

    bool parse_and(Expr* out, std::string* error) {
        if (!parse_cmp(out, error)) return false;
        while (tok_.kind == TokenKind::AmpAmp) {
            if (!require_ops(error, tok_.line, "&&")) return false;
            Expr rhs;
            const std::string op = tok_.text;
            const int line = out->line;
            advance();
            if (!parse_cmp(&rhs, error)) return false;
            *out = make_binary(ExprKind::Binary, op, *out, rhs, line);
        }
        return true;
    }

    bool parse_cmp(Expr* out, std::string* error) {
        if (!parse_add(out, error)) return false;
        while (tok_.kind == TokenKind::EqEq || tok_.kind == TokenKind::NotEq ||
               tok_.kind == TokenKind::Lt || tok_.kind == TokenKind::Gt ||
               tok_.kind == TokenKind::Le || tok_.kind == TokenKind::Ge) {
            // == and != were allowed for get_entity_type before Operators.
            const bool eqish = tok_.kind == TokenKind::EqEq || tok_.kind == TokenKind::NotEq;
            if (!eqish && !operators_unlocked()) {
                set_error(error, line_prefix(tok_.line) + "比较运算符尚未解锁。到技能树花费木头和干草即可使用 < > <= >=。",
                          current_span(), ErrorKind::LockedSyntax, "到技能树解锁运算符", tok_.text);
                return false;
            }
            Expr rhs;
            const std::string op = tok_.text;
            const int line = out->line;
            advance();
            if (!parse_add(&rhs, error)) return false;
            // Keep Compare form when left is a no-arg / simple call and right is ident (old tests).
            *out = make_binary(ExprKind::Binary, op, *out, rhs, line);
        }
        return true;
    }

    bool parse_add(Expr* out, std::string* error) {
        if (!parse_mul(out, error)) return false;
        while (tok_.kind == TokenKind::Plus || tok_.kind == TokenKind::Minus) {
            if (!require_ops(error, tok_.line, tok_.text.c_str())) return false;
            Expr rhs;
            const std::string op = tok_.text;
            const int line = out->line;
            advance();
            if (!parse_mul(&rhs, error)) return false;
            *out = make_binary(ExprKind::Binary, op, *out, rhs, line);
        }
        return true;
    }

    bool parse_mul(Expr* out, std::string* error) {
        if (!parse_unary(out, error)) return false;
        while (tok_.kind == TokenKind::Star || tok_.kind == TokenKind::Slash ||
               tok_.kind == TokenKind::Percent) {
            if (!require_ops(error, tok_.line, tok_.text.c_str())) return false;
            Expr rhs;
            const std::string op = tok_.text;
            const int line = out->line;
            advance();
            if (!parse_unary(&rhs, error)) return false;
            *out = make_binary(ExprKind::Binary, op, *out, rhs, line);
        }
        return true;
    }

    bool require_ops(std::string* error, int line, const char* op) {
        if (operators_unlocked()) return true;
        set_error(error, line_prefix(line) + "算术与逻辑运算符尚未解锁。到技能树花费木头和干草即可使用 " +
                          std::string(op) + "。",
                  current_span(), ErrorKind::LockedSyntax, "到技能树解锁运算符", op);
        return false;
    }

    static Expr make_binary(ExprKind kind, const std::string& op, const Expr& a, const Expr& b, int line) {
        Expr e;
        e.kind = kind;
        e.op = op;
        e.line = line;
        e.span = a.span;
        e.kids.push_back(a);
        e.kids.push_back(b);
        return e;
    }

    bool parse_unary(Expr* out, std::string* error) {
        if (tok_.kind == TokenKind::Bang || tok_.kind == TokenKind::Minus || tok_.kind == TokenKind::Plus) {
            if (tok_.kind != TokenKind::Minus && tok_.kind != TokenKind::Plus && !operators_unlocked()) {
                set_error(error, line_prefix(tok_.line) + "逻辑非尚未解锁。到技能树解锁运算符即可使用 !。",
                          current_span(), ErrorKind::LockedSyntax, "到技能树解锁运算符", "!");
                return false;
            }
            if ((tok_.kind == TokenKind::Minus || tok_.kind == TokenKind::Plus) && !operators_unlocked() &&
                !variables_unlocked()) {
                // allow unary minus only with operators
                set_error(error, line_prefix(tok_.line) + "运算符尚未解锁。", current_span(), ErrorKind::LockedSyntax,
                          "到技能树解锁运算符", tok_.text);
                return false;
            }
            const std::string op = tok_.text;
            const int line = tok_.line;
            const SourceSpan sp = current_span();
            advance();
            Expr inner;
            if (!parse_unary(&inner, error)) return false;
            out->kind = ExprKind::Unary;
            out->op = op;
            out->line = line;
            out->span = sp;
            out->kids.push_back(std::move(inner));
            return true;
        }
        if (tok_.kind == TokenKind::PlusPlus || tok_.kind == TokenKind::MinusMinus) {
            if (!variables_unlocked()) {
                set_error(error, line_prefix(tok_.line) + "变量尚未解锁，不能使用 ++。", current_span(),
                          ErrorKind::LockedSyntax, "到技能树解锁变量", "++");
                return false;
            }
            const std::string op = std::string("pre") + tok_.text;
            const int line = tok_.line;
            advance();
            Expr inner;
            if (!parse_unary(&inner, error)) return false;
            out->kind = ExprKind::Unary;
            out->op = op;
            out->line = line;
            out->kids.push_back(std::move(inner));
            return true;
        }
        return parse_postfix(out, error);
    }

    bool parse_postfix(Expr* out, std::string* error) {
        if (!parse_primary(out, error)) return false;
        for (;;) {
            if (tok_.kind == TokenKind::LBracket) {
                if (!arrays_unlocked()) {
                    set_error(error, line_prefix(tok_.line) + "数组尚未解锁。到技能树花费胡萝卜即可使用下标。",
                              current_span(), ErrorKind::LockedSyntax, "到技能树解锁数组", "[]");
                    return false;
                }
                advance();
                Expr idx;
                if (!parse_expr(&idx, error)) return false;
                if (!expect(TokenKind::RBracket, error, out->line, "这里需要 ']'。")) return false;
                Expr acc;
                acc.kind = ExprKind::Index;
                acc.line = out->line;
                acc.span = out->span;
                acc.kids.push_back(*out);
                acc.kids.push_back(std::move(idx));
                *out = std::move(acc);
                continue;
            }
            if (tok_.kind == TokenKind::Dot) {
                advance();
                if (tok_.kind != TokenKind::Ident) {
                    set_error(error, line_prefix(out->line) + "点号后面需要成员名。", current_span(), ErrorKind::Generic);
                    return false;
                }
                Expr mem;
                mem.kind = ExprKind::Member;
                mem.name = tok_.text;
                mem.line = out->line;
                mem.span = out->span;
                mem.kids.push_back(*out);
                advance();
                *out = std::move(mem);
                continue;
            }
            if (tok_.kind == TokenKind::PlusPlus || tok_.kind == TokenKind::MinusMinus) {
                if (!variables_unlocked()) {
                    set_error(error, line_prefix(tok_.line) + "变量尚未解锁，不能使用 ++。", current_span(),
                              ErrorKind::LockedSyntax);
                    return false;
                }
                Expr u;
                u.kind = ExprKind::Unary;
                u.op = std::string("post") + tok_.text;
                u.line = out->line;
                u.kids.push_back(*out);
                advance();
                *out = std::move(u);
                continue;
            }
            break;
        }
        return true;
    }

    bool parse_primary(Expr* out, std::string* error) {
        if (tok_.kind == TokenKind::KwTrue) {
            out->kind = ExprKind::LiteralTrue;
            out->line = tok_.line;
            out->span = current_span();
            out->int_val = 1;
            advance();
            return true;
        }
        if (tok_.kind == TokenKind::KwFalse) {
            out->kind = ExprKind::LiteralFalse;
            out->line = tok_.line;
            out->span = current_span();
            out->int_val = 0;
            advance();
            return true;
        }
        if (tok_.kind == TokenKind::Number) {
            out->kind = ExprKind::LiteralInt;
            out->line = tok_.line;
            out->span = current_span();
            if (tok_.text.find('.') != std::string::npos) {
                out->kind = ExprKind::LiteralReal;
                out->real_val = std::stod(tok_.text);
            } else {
                out->int_val = std::stoll(tok_.text);
            }
            advance();
            return true;
        }
        if (tok_.kind == TokenKind::String) {
            out->kind = ExprKind::LiteralString;
            out->text = tok_.text;
            out->line = tok_.line;
            out->span = current_span();
            advance();
            return true;
        }
        if (tok_.kind == TokenKind::LParen) {
            open_stack_.push_back(tok_);
            advance();
            if (!parse_expr(out, error)) return false;
            return expect(TokenKind::RParen, error, out->line, "这里需要 ')'。");
        }
        if (tok_.kind == TokenKind::Ident) {
            const Token name_tok = tok_;
            const int line = tok_.line;
            std::string name = tok_.text;
            const SourceSpan name_span = current_span();
            advance();
            if (tok_.kind == TokenKind::ColonColon) {
                advance();
                if (tok_.kind == TokenKind::Ident) {
                    name = name + "::" + tok_.text;
                    // Use the enum member as Ident (dir_from_name accepts Dir::East).
                    // Also allow just the last component as ident name for Entity::Bush?
                    // We'll store the full name; eval will try both.
                    out->kind = ExprKind::Ident;
                    out->name = name;
                    out->line = line;
                    out->span = name_span;
                    advance();
                    return true;
                }
            }
            if (tok_.kind == TokenKind::LParen) {
                open_stack_.push_back(tok_);
                advance();
                std::vector<Expr> args;
                auto is_expr_start = [&]() {
                    const auto k = tok_.kind;
                    return k == TokenKind::Ident || k == TokenKind::Number || k == TokenKind::String ||
                           k == TokenKind::KwTrue || k == TokenKind::KwFalse || k == TokenKind::LParen ||
                           k == TokenKind::Minus || k == TokenKind::Plus || k == TokenKind::Bang ||
                           k == TokenKind::PlusPlus || k == TokenKind::MinusMinus;
                };
                if (tok_.kind != TokenKind::RParen) {
                    if (!is_expr_start()) {
                        return expect(TokenKind::RParen, error, line, "这里需要 ')'。");
                    }
                    for (;;) {
                        Expr a;
                        if (!parse_expr(&a, error)) return false;
                        args.push_back(std::move(a));
                        if (tok_.kind == TokenKind::Comma) {
                            advance();
                            continue;
                        }
                        break;
                    }
                }
                if (!expect(TokenKind::RParen, error, line, "这里需要 ')'。")) return false;
                if (!check_call_unlock(name, name_span, line, error)) return false;
                out->kind = ExprKind::Call;
                out->name = name;
                out->line = line;
                out->span = name_span;
                out->kids = std::move(args);
                if (out->kids.size() == 1 && out->kids[0].kind == ExprKind::Ident) {
                    out->arg = out->kids[0].name;
                }
                return true;
            }
            // Bare identifier: enum literals always ok; variables need unlock.
            if (is_enum_name(name) || name == "true" || name == "false") {
                out->kind = ExprKind::Ident;
                out->name = name;
                out->line = line;
                out->span = name_span;
                return true;
            }
            if (!variables_unlocked() && !const_unlocked()) {
                if (for_unlocked()) {
                    // Most likely the for counter: say what is missing.
                    set_error(error, line_prefix(line) + "变量尚未解锁：“" + name +
                                         "” 只能用来数圈，还不能写进判断或表达式。到技能树花 70 干草或 25 木头解锁变量。",
                              name_span, ErrorKind::LockedSyntax, "到技能树解锁变量", "vars");
                    return false;
                }
                // Same diagnostic as 0.1.5: identifiers must be calls.
                set_error(error, line_prefix(line) + "“" + name + "” 后面需要括号 ()。第一期只支持函数调用。",
                          name_span, ErrorKind::Generic);
                return false;
            }
            out->kind = ExprKind::Ident;
            out->name = name;
            out->line = line;
            out->span = name_span;
            return true;
        }
        if (tok_.kind == TokenKind::Unknown) {
            set_error(error, line_prefix(tok_.line) + "无法识别的字符 “" + tok_.text + "”。", current_span(),
                      ErrorKind::Generic);
            return false;
        }
        if (tok_.kind == TokenKind::End) {
            set_error(error, "代码不完整，似乎少了表达式。", SourceSpan{1, 1, 2}, ErrorKind::Generic);
            return false;
        }
        set_error(error, line_prefix(tok_.line) + "这里需要表达式，例如 harvest() 或 true。", current_span(),
                  ErrorKind::Generic);
        return false;
    }

    static bool is_enum_name(const std::string& name) {
        Dir d; EntityType e; GroundType g; Item it; UnlockId u; Hat h;
        return dir_from_name(name, &d) || entity_from_name(name, &e) || ground_from_name(name, &g) ||
               item_from_name(name, &it) || unlock_id_from_name(name, &u) || hat_from_name(name, &h);
    }

    bool check_call_unlock(const std::string& name, SourceSpan name_span, int line, std::string* error) {
        auto locked = [&](const std::string& msg, const std::string& sug, const std::string& word) {
            set_error(error, line_prefix(line) + msg, name_span, ErrorKind::LockedSyntax, sug, word);
            return false;
        };
        if (name == "move" && !movement_unlocked()) {
            return locked("移动尚未解锁。到技能树花 20 个干草即可使用 move()，农场也会扩大到 3×3。",
                          "到技能树花 20 个干草解锁", "move");
        }
        if (name == "till" && !till_unlocked()) {
            return locked("耕地尚未解锁。到技能树花 40 个干草即可使用 till()。", "到技能树花 40 个干草解锁", "till");
        }
        if (name == "can_harvest" && !conditions_unlocked()) {
            return locked("条件判断尚未解锁。到技能树花 12 个干草即可使用 if 和 can_harvest()。",
                          "到技能树花 12 个干草解锁", "can_harvest");
        }
        if ((name == "plant" || name == "get_entity_type" || name == "get_ground_type") && !plant_unlocked()) {
            return locked("种植尚未解锁。到技能树花 60 个干草即可使用 plant()、get_entity_type() 和 get_ground_type()。",
                          "到技能树花 60 个干草解锁", name);
        }
        if ((name == "get_pos_x" || name == "get_pos_y" || name == "num_items" || name == "num_unlocked") &&
            !senses_unlocked()) {
            return locked("感知尚未解锁。到技能树花费木头或干草即可使用 get_pos_x() 等。", "到技能树解锁感知", name);
        }
        if (name == "get_world_size" && !expand_unlocked()) {
            return locked("get_world_size() 尚未解锁。购买下一次扩田后即可使用。", "到技能树解锁扩田", name);
        }
        if (name == "get_cost" && world_ && !world_->is_unlocked(UnlockId::Costs) &&
            !world_->is_unlocked(UnlockId::Carrots)) {
            return locked("get_cost() 尚未解锁。种植胡萝卜后即可查询成本。", "到技能树解锁成本查询", name);
        }
        if ((name == "use_item" || name == "get_water") && world_ &&
            !world_->is_unlocked(UnlockId::Watering) && !world_->is_unlocked(UnlockId::Fertilizer)) {
            return locked("物品与浇水尚未解锁。", "到技能树解锁浇水", name);
        }
        if (name == "measure" && world_ && !world_->is_unlocked(UnlockId::Sunflowers)) {
            return locked("measure() 尚未解锁。解锁向日葵后即可测量。", "到技能树解锁向日葵", name);
        }
        if (name == "can_move" && world_ && !world_->is_unlocked(UnlockId::Mazes) &&
            !world_->is_unlocked(UnlockId::Dinosaurs)) {
            return locked("can_move() 尚未解锁。解锁迷宫后即可使用。", "到技能树解锁迷宫", name);
        }
        if (name == "swap" && world_ && !world_->is_unlocked(UnlockId::Cactus)) {
            return locked("swap() 尚未解锁。解锁仙人掌后即可使用。", "到技能树解锁仙人掌", name);
        }
        if (name == "get_companion" && world_ && !world_->is_unlocked(UnlockId::Companions)) {
            return locked("get_companion() 尚未解锁。", "到技能树解锁伴侣种植", name);
        }
        if (name == "change_hat" && world_ && !world_->is_unlocked(UnlockId::Dinosaurs) &&
            !world_->is_unlocked(UnlockId::Hats)) {
            return locked("change_hat() 尚未解锁。", "到技能树解锁恐龙", name);
        }
        if ((name == "spawn_drone" || name == "wait_for" || name == "has_finished" || name == "num_drones" ||
             name == "max_drones") &&
            world_ && !world_->is_unlocked(UnlockId::Megafarm)) {
            return locked("多种无人机尚未解锁。", "到技能树解锁多无人机", name);
        }
        if ((name == "quick_print") && world_ && !world_->is_unlocked(UnlockId::Debug)) {
            return locked("quick_print 尚未解锁。", "到技能树解锁调试", name);
        }
        if ((name == "print" || name == "print_slow") && world_ && !world_->is_unlocked(UnlockId::Debug) &&
            !world_->is_unlocked(UnlockId::Timing)) {
            return locked("print 尚未解锁。", "到技能树解锁调试", name);
        }
        if ((name == "get_time" || name == "get_tick_count") && world_ &&
            !world_->is_unlocked(UnlockId::Timing)) {
            return locked("计时尚未解锁。", "到技能树解锁计时", name);
        }
        if ((name == "set_world_size" || name == "set_execution_speed") && world_ &&
            !world_->is_unlocked(UnlockId::Debug2)) {
            return locked("实验尚未解锁。", "到技能树解锁实验", name);
        }
        if (name == "simulate" && world_ && !world_->is_unlocked(UnlockId::Simulation)) {
            return locked("simulate() 尚未解锁。到技能树解锁模拟后即可用固定种子重放。", "到技能树解锁模拟", name);
        }
        if ((name == "min" || name == "max" || name == "abs" || name == "std::min" || name == "std::max" ||
             name == "std::abs" || name == "random01") &&
            world_ && !world_->utilities_unlocked()) {
            return locked("工具函数尚未解锁。", "到技能树解锁工具函数", name);
        }
        if (!is_builtin_name(name)) {
            const std::string sug = suggest_identifier(name, unlocked_idents());
            std::string msg = line_prefix(line) + "未知函数 “" + name + "()”。";
            std::string suggestion;
            if (!sug.empty()) {
                suggestion = "是 " + sug + " 吗？";
                msg += suggestion;
            }
            set_error(error, msg, name_span, ErrorKind::Typo, suggestion, name);
            return false;
        }
        return true;
    }

    bool expect(TokenKind kind, std::string* error, int line, const std::string& message) {
        if (tok_.kind == kind) {
            if (kind == TokenKind::LParen || kind == TokenKind::LBrace) {
                open_stack_.push_back(tok_);
            }
            if ((kind == TokenKind::RParen || kind == TokenKind::RBrace) && !open_stack_.empty()) {
                open_stack_.pop_back();
            }
            advance();
            return true;
        }
        const bool at_end = tok_.kind == TokenKind::End;
        SourceSpan span = at_end ? SourceSpan{line, 1, 2} : current_span();
        ErrorKind ek = ErrorKind::Generic;
        std::string suggestion;
        std::string msg = message;
        if (kind == TokenKind::Semicolon) {
            ek = ErrorKind::MissingSemicolon;
            if (prev_.line > 0) span = span_after(prev_);
            if (msg.find("分号") == std::string::npos) {
                msg = "这里少了分号 ;";
            } else if (msg.find("这里少了") == std::string::npos) {
                msg = "这里少了分号 ;";
            }
            suggestion = "在这里加上 ;";
        } else if (kind == TokenKind::RParen || kind == TokenKind::RBrace) {
            ek = ErrorKind::Unclosed;
            if (!open_stack_.empty()) span = span_of(open_stack_.back());
            suggestion = kind == TokenKind::RParen ? "补上 )" : "补上 }";
        }
        const int msg_line = (ek == ErrorKind::MissingSemicolon || ek == ErrorKind::Unclosed)
                                 ? span.line
                                 : (at_end ? line : tok_.line);
        set_error(error, line_prefix(msg_line) + msg, span, ek, suggestion);
        return false;
    }

    void advance() {
        prev_ = tok_;
        tok_ = lexer_.next();
    }

    Lexer lexer_;
    const World* world_ = nullptr;
    Token tok_;
};

}  // namespace codefarm::detail
