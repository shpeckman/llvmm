# spec/toy_compiler_spec.cr
require "./spec_helper"

private module Toy
  enum TokenKind
    Num
    Ident
    KwDef
    KwLet
    KwIn
    KwIf
    KwThen
    KwElse
    KwWhile
    KwDo
    OpPlus
    OpMinus
    OpStar
    OpSlash
    OpLt
    OpLe
    OpGt
    OpGe
    OpEq
    OpNe
    OpAssign
    LParen
    RParen
    Comma
    Eof
  end

  record Token, kind : TokenKind, text : String, value : Int32

  KEYWORDS = {
    "def"   => TokenKind::KwDef,
    "let"   => TokenKind::KwLet,
    "in"    => TokenKind::KwIn,
    "if"    => TokenKind::KwIf,
    "then"  => TokenKind::KwThen,
    "else"  => TokenKind::KwElse,
    "while" => TokenKind::KwWhile,
    "do"    => TokenKind::KwDo,
  }

  CMP_OPS = {
    TokenKind::OpLt => "<",
    TokenKind::OpLe => "<=",
    TokenKind::OpGt => ">",
    TokenKind::OpGe => ">=",
    TokenKind::OpEq => "==",
    TokenKind::OpNe => "!=",
  }

  ADD_OPS = {
    TokenKind::OpPlus  => "+",
    TokenKind::OpMinus => "-",
  }

  MUL_OPS = {
    TokenKind::OpStar  => "*",
    TokenKind::OpSlash => "/",
  }

  class Lit
    getter value : Int32

    def initialize(@value : Int32)
    end
  end

  class Var
    getter name : String

    def initialize(@name : String)
    end
  end

  class Bin
    getter op    : String
    getter left  : Expr
    getter right : Expr

    def initialize(@op : String, @left : Expr, @right : Expr)
    end
  end

  class Neg
    getter operand : Expr

    def initialize(@operand : Expr)
    end
  end

  class Let
    getter name  : String
    getter value : Expr
    getter body  : Expr

    def initialize(@name : String, @value : Expr, @body : Expr)
    end
  end

  class Assign
    getter name  : String
    getter value : Expr

    def initialize(@name : String, @value : Expr)
    end
  end

  class If
    getter cond   : Expr
    getter then_e : Expr
    getter else_e : Expr

    def initialize(@cond : Expr, @then_e : Expr, @else_e : Expr)
    end
  end

  class While
    getter cond : Expr
    getter body : Expr

    def initialize(@cond : Expr, @body : Expr)
    end
  end

  class Call
    getter name : String
    getter args : Array(Expr)

    def initialize(@name : String, @args : Array(Expr))
    end
  end

  record FunDef, name : String, params : Array(String), body : Expr
  record Program, defs : Array(FunDef), expr : Expr

  alias Expr = Lit | Var | Bin | Neg | Let | Assign | If | While | Call

  def self.compile(context : LLVMM::Context, source : String) : LLVMM::Module
    program = Parser.new(Lexer.new(source)).parse_program
    mod     = context.new_module("toy")
    Codegen.new(context, mod, program).generate
    mod
  end

  class Lexer
    def initialize(@src : String)
      @pos = 0
    end

    def offset : Int32
      @pos
    end

    def next_token : Token
      skip_space
      return Token.new(TokenKind::Eof, "", 0) if @pos >= @src.bytesize

      case @src[@pos]
      when '0'..'9'
        lex_number
      when 'a'..'z', 'A'..'Z', '_'
        lex_ident
      when '+'
        advance(TokenKind::OpPlus, "+")
      when '-'
        advance(TokenKind::OpMinus, "-")
      when '*'
        advance(TokenKind::OpStar, "*")
      when '/'
        advance(TokenKind::OpSlash, "/")
      when '('
        advance(TokenKind::LParen, "(")
      when ')'
        advance(TokenKind::RParen, ")")
      when ','
        advance(TokenKind::Comma, ",")
      when '<'
        peek_char == '=' ? advance2(TokenKind::OpLe, "<=") : advance(TokenKind::OpLt, "<")
      when '>'
        peek_char == '=' ? advance2(TokenKind::OpGe, ">=") : advance(TokenKind::OpGt, ">")
      when '='
        peek_char == '=' ? advance2(TokenKind::OpEq, "==") : advance(TokenKind::OpAssign, "=")
      when '!'
        unless peek_char == '='
          raise "unexpected character '!' at offset #{@pos} (did you mean '!='?)"
        end
        advance2(TokenKind::OpNe, "!=")
      else
        raise "unexpected character #{@src[@pos].inspect} at offset #{@pos}"
      end
    end

    private def skip_space
      while @pos < @src.bytesize && @src[@pos].whitespace?
        @pos += 1
      end
    end

    private def peek_char : Char?
      @pos + 1 < @src.bytesize ? @src[@pos + 1] : nil
    end

    private def advance(kind : TokenKind, text : String) : Token
      @pos += 1
      Token.new(kind, text, 0)
    end

    private def advance2(kind : TokenKind, text : String) : Token
      @pos += 2
      Token.new(kind, text, 0)
    end

    private def lex_number : Token
      start = @pos
      while @pos < @src.bytesize && @src[@pos].ascii_number?
        @pos += 1
      end
      text  = @src[start...@pos]
      value = text.to_i32? || raise "invalid number literal: #{text}"
      Token.new(TokenKind::Num, text, value)
    end

    private def lex_ident : Token
      start = @pos
      while @pos < @src.bytesize
        char = @src[@pos]
        break unless char.ascii_alphanumeric? || char == '_'
        @pos += 1
      end
      text = @src[start...@pos]
      Token.new(KEYWORDS[text]? || TokenKind::Ident, text, 0)
    end
  end

  class Parser
    def initialize(@lexer : Lexer)
      @current = @lexer.next_token
    end

    def parse_program : Program
      defs = [] of FunDef
      while @current.kind.kw_def?
        defs << parse_def
      end
      expr = parse_expr
      expect(TokenKind::Eof)
      Program.new(defs, expr)
    end

    private def parse_def : FunDef
      expect(TokenKind::KwDef)
      name = expect_ident
      expect(TokenKind::LParen)
      params = [] of String
      until @current.kind.r_paren?
        params << expect_ident
        break unless @current.kind.comma?
        expect(TokenKind::Comma)
      end
      expect(TokenKind::RParen)
      expect(TokenKind::OpAssign)
      FunDef.new(name, params, parse_expr)
    end

    private def parse_expr : Expr
      case @current.kind
      when .kw_let?
        parse_let
      when .kw_if?
        parse_if
      when .kw_while?
        parse_while
      else
        assign_or(parse_cmp)
      end
    end

    private def assign_or(target : Expr) : Expr
      return target unless @current.kind.op_assign?
      unless target.is_a?(Var)
        raise "invalid assignment target near #{@current.text.inspect}"
      end
      advance
      Assign.new(target.name, parse_expr)
    end

    private def parse_let : Expr
      expect(TokenKind::KwLet)
      name = expect_ident
      expect(TokenKind::OpAssign)
      value = parse_expr
      expect(TokenKind::KwIn)
      Let.new(name, value, parse_expr)
    end

    private def parse_if : Expr
      expect(TokenKind::KwIf)
      cond = parse_expr
      expect(TokenKind::KwThen)
      then_e = parse_expr
      expect(TokenKind::KwElse)
      If.new(cond, then_e, parse_expr)
    end

    private def parse_while : Expr
      expect(TokenKind::KwWhile)
      cond = parse_expr
      expect(TokenKind::KwDo)
      While.new(cond, parse_expr)
    end

    private def parse_cmp : Expr
      left = parse_add
      loop do
        op = CMP_OPS[@current.kind]?
        break unless op
        advance
        left = Bin.new(op, left, parse_add)
      end
      left
    end

    private def parse_add : Expr
      left = parse_mul
      loop do
        op = ADD_OPS[@current.kind]?
        break unless op
        advance
        left = Bin.new(op, left, parse_mul)
      end
      left
    end

    private def parse_mul : Expr
      left = parse_unary
      loop do
        op = MUL_OPS[@current.kind]?
        break unless op
        advance
        left = Bin.new(op, left, parse_unary)
      end
      left
    end

    private def parse_unary : Expr
      if @current.kind.op_minus?
        advance
        Neg.new(parse_unary)
      else
        parse_primary
      end
    end

    private def parse_primary : Expr
      case @current.kind
      when .num?
        Lit.new(advance.value)
      when .ident?
        name = advance.text
        return Var.new(name) unless @current.kind.l_paren?
        advance
        args = [] of Expr
        until @current.kind.r_paren?
          args << parse_expr
          break unless @current.kind.comma?
          expect(TokenKind::Comma)
        end
        expect(TokenKind::RParen)
        Call.new(name, args)
      when .l_paren?
        advance
        expr = parse_expr
        expect(TokenKind::RParen)
        expr
      else
        raise "unexpected token #{@current.text.inspect} at offset #{@lexer.offset}"
      end
    end

    private def expect(kind : TokenKind) : Token
      unless @current.kind == kind
        raise "expected #{kind}, got #{@current.kind} (#{@current.text.inspect})"
      end
      advance
    end

    private def expect_ident : String
      unless @current.kind.ident?
        raise "expected identifier, got #{@current.text.inspect}"
      end
      advance.text
    end

    private def advance : Token
      token    = @current
      @current = @lexer.next_token
      token
    end
  end

  class Codegen
    @functions = {} of String => LLVMM::Function
    @current_fun : LLVMM::Function?

    def initialize(@context : LLVMM::Context, @mod : LLVMM::Module, @program : Program)
      @builder = @context.new_builder
      @int     = @context.int32
    end

    def generate : Nil
      @program.defs.each do |defn|
        raise "reserved function name 'toy_main'" if defn.name == "toy_main"
      end
      defs = @program.defs + [FunDef.new("toy_main", [] of String, @program.expr)]
      defs.each do |defn|
        raise "duplicate function '#{defn.name}'" if @functions.has_key?(defn.name)
        func = @mod.functions.add(defn.name, Array(LLVMM::Type).new(defn.params.size, @int), @int)
        defn.params.each_with_index { |param, i| func.params[i].name = param }
        @functions[defn.name] = func
      end
      defs.each { |defn| build_function(defn) }
    end

    private def build_function(defn : FunDef) : Nil
      func         = @functions[defn.name]
      @current_fun = func
      @builder.position_at_end(func.basic_blocks.append("entry"))
      env = {} of String => LLVMM::Value
      defn.params.each_with_index do |param, i|
        slot = @builder.alloca(@int, param)
        @builder.store(func.params[i], slot)
        env[param] = slot
      end
      @builder.ret(codegen(defn.body, env))
    end

    private def codegen(expr : Expr, env : Hash(String, LLVMM::Value)) : LLVMM::Value
      case expr
      in Lit
        @int.const_int(expr.value)
      in Var
        load_var(expr.name, env)
      in Bin
        binop(expr.op, codegen(expr.left, env), codegen(expr.right, env))
      in Neg
        @builder.neg(codegen(expr.operand, env))
      in Let
        bind(expr, env)
      in Assign
        assign(expr, env)
      in If
        branch_if(expr, env)
      in While
        loop_while(expr, env)
      in Call
        call(expr, env)
      end
    end

    private def load_var(name : String, env : Hash(String, LLVMM::Value)) : LLVMM::Value
      slot = env[name]? || raise "unknown variable '#{name}'"
      @builder.load(@int, slot, name)
    end

    private def bind(expr : Let, env : Hash(String, LLVMM::Value)) : LLVMM::Value
      value = codegen(expr.value, env)
      slot  = @builder.alloca(@int, expr.name)
      @builder.store(value, slot)
      scoped = env.dup
      scoped[expr.name] = slot
      codegen(expr.body, scoped)
    end

    private def assign(expr : Assign, env : Hash(String, LLVMM::Value)) : LLVMM::Value
      slot  = env[expr.name]? || raise "unknown variable '#{expr.name}'"
      value = codegen(expr.value, env)
      @builder.store(value, slot)
      value
    end

    private def branch_if(expr : If, env : Hash(String, LLVMM::Value)) : LLVMM::Value
      cond     = truthy(codegen(expr.cond, env))
      then_bb  = append_block("if.then")
      else_bb  = append_block("if.else")
      merge_bb = append_block("if.merge")
      @builder.cond(cond, then_bb, else_bb)

      @builder.position_at_end(then_bb)
      then_val = codegen(expr.then_e, env)
      then_end = @builder.insert_block
      @builder.br(merge_bb)

      @builder.position_at_end(else_bb)
      else_val = codegen(expr.else_e, env)
      else_end = @builder.insert_block
      @builder.br(merge_bb)

      @builder.position_at_end(merge_bb)
      table = LLVMM::PhiTable.new
      table.add(then_end, then_val)
      table.add(else_end, else_val)
      @builder.phi(@int, table, "iftmp")
    end

    private def loop_while(expr : While, env : Hash(String, LLVMM::Value)) : LLVMM::Value
      cond_bb = append_block("while.cond")
      body_bb = append_block("while.body")
      end_bb  = append_block("while.end")
      @builder.br(cond_bb)

      @builder.position_at_end(cond_bb)
      @builder.cond(truthy(codegen(expr.cond, env)), body_bb, end_bb)

      @builder.position_at_end(body_bb)
      codegen(expr.body, env)
      @builder.br(cond_bb)

      @builder.position_at_end(end_bb)
      @int.const_int(0)
    end

    private def call(expr : Call, env : Hash(String, LLVMM::Value)) : LLVMM::Value
      func     = @functions[expr.name]? || raise "unknown function '#{expr.name}'"
      expected = func.params.size
      unless expr.args.size == expected
        raise "'#{expr.name}' expects #{expected} argument(s), got #{expr.args.size}"
      end
      args = expr.args.map { |arg| codegen(arg, env) }
      @builder.call(func.function_type, func, args, "calltmp")
    end

    private def binop(op : String, lhs : LLVMM::Value, rhs : LLVMM::Value) : LLVMM::Value
      case op
      when "+"  then @builder.add(lhs, rhs, "addtmp")
      when "-"  then @builder.sub(lhs, rhs, "subtmp")
      when "*"  then @builder.mul(lhs, rhs, "multmp")
      when "/"  then @builder.sdiv(lhs, rhs, "divtmp")
      when "<"  then as_int(@builder.icmp(LLVMM::IntPredicate::SLT, lhs, rhs, "cmptmp"))
      when "<=" then as_int(@builder.icmp(LLVMM::IntPredicate::SLE, lhs, rhs, "cmptmp"))
      when ">"  then as_int(@builder.icmp(LLVMM::IntPredicate::SGT, lhs, rhs, "cmptmp"))
      when ">=" then as_int(@builder.icmp(LLVMM::IntPredicate::SGE, lhs, rhs, "cmptmp"))
      when "==" then as_int(@builder.icmp(LLVMM::IntPredicate::EQ, lhs, rhs, "cmptmp"))
      when "!=" then as_int(@builder.icmp(LLVMM::IntPredicate::NE, lhs, rhs, "cmptmp"))
      else           raise "unknown operator '#{op}'"
      end
    end

    private def as_int(cond : LLVMM::Value) : LLVMM::Value
      @builder.zext(cond, @int, "booltmp")
    end

    private def truthy(value : LLVMM::Value) : LLVMM::Value
      @builder.icmp(LLVMM::IntPredicate::NE, value, @int.const_int(0), "truthy")
    end

    private def append_block(name : String) : LLVMM::BasicBlock
      @current_fun.not_nil!.basic_blocks.append(name)
    end
  end
end

private def compile(source : String) : LLVMM::Module
  LLVMM.init_native_target
  mod = Toy.compile(LLVMM::Context.new, source)
  mod.verify
  mod
end

private def jit(mod : LLVMM::Module, &)
  LLVMM::JITCompiler.new(mod) { |engine| yield engine }
end

private def run(engine : LLVMM::JITCompiler, name : String = "toy_main") : Int32
  Proc(Int32).new(engine.function_address(name), Pointer(Void).null).call
end

describe "toy expression compiler" do
  it "evaluates arithmetic with correct precedence" do
    jit(compile("2 + 3 * 4")) { |engine| run(engine).should eq(14) }
    jit(compile("(2 + 3) * 4")) { |engine| run(engine).should eq(20) }
    jit(compile("10 - 4 - 3")) { |engine| run(engine).should eq(3) }
    jit(compile("7 / 2")) { |engine| run(engine).should eq(3) }
    jit(compile("-5 + 3")) { |engine| run(engine).should eq(-2) }
    jit(compile("-(2 * 3)")) { |engine| run(engine).should eq(-6) }
  end

  it "compares values" do
    jit(compile("3 < 4")) { |engine| run(engine).should eq(1) }
    jit(compile("4 <= 4")) { |engine| run(engine).should eq(1) }
    jit(compile("5 == 5")) { |engine| run(engine).should eq(1) }
    jit(compile("5 != 5")) { |engine| run(engine).should eq(0) }
    jit(compile("10 < 5")) { |engine| run(engine).should eq(0) }
    jit(compile("(3 < 4) + 8")) { |engine| run(engine).should eq(9) }
  end

  it "selects branches with if" do
    jit(compile("if 1 < 2 then 10 else 20")) { |engine| run(engine).should eq(10) }
    jit(compile("let x = 5 in if x < 4 then x * 2 else x + 2")) { |engine| run(engine).should eq(7) }
    jit(compile(<<-SRC)) { |engine| run(engine).should eq(2) }
      if 3 < 4 then if 1 == 1 then 2 else 3 else 4
      SRC
  end

  it "binds and shadows locals" do
    jit(compile("let x = 3 in x * 2")) { |engine| run(engine).should eq(6) }
    jit(compile("let x = 1 in (let x = 2 in x) + x")) { |engine| run(engine).should eq(3) }
    jit(compile("let x = 2 in let y = x + 1 in x * y")) { |engine| run(engine).should eq(6) }
  end

  it "accumulates through while loops and assignment" do
    jit(compile(<<-SRC)) { |engine| run(engine).should eq(55) }
      let n = 10 in
      let acc = 0 in
      let _go = while n > 0 do
        let step = acc + n in
        let _set = acc = step in
        n = n - 1
      in acc
      SRC
  end

  it "runs iterative and recursive functions" do
    jit(compile(<<-SRC)) { |engine| run(engine).should eq(120) }
      def fact_iter(n) =
        let acc = 1 in
        let _go = while n > 1 do
          let a = acc * n in
          let _ = acc = a in
          n = n - 1
        in acc
      fact_iter(5)
      SRC

    jit(compile(<<-SRC)) { |engine| run(engine).should eq(120) }
      def fact(n) = if n <= 1 then 1 else n * fact(n - 1)
      fact(5)
      SRC

    jit(compile(<<-SRC)) { |engine| run(engine).should eq(55) }
      def fib(n) = if n <= 1 then n else fib(n - 1) + fib(n - 2)
      fib(10)
      SRC
  end

  it "calls multi-argument and mutually recursive functions" do
    jit(compile(<<-SRC)) { |engine| run(engine).should eq(6) }
      def add3(a, b, c) = a + b + c
      add3(1, 2, 3)
      SRC

    jit(compile(<<-SRC)) { |engine| run(engine).should eq(1) }
      def is_even(n) = if n == 0 then 1 else is_odd(n - 1)
      def is_odd(n) = if n == 0 then 0 else is_even(n - 1)
      is_even(10)
      SRC
  end

  it "rejects unknown names" do
    expect_raises(Exception, "unknown variable") { compile("x + 1") }
    expect_raises(Exception, "unknown function") { compile("nope(1)") }
    expect_raises(Exception, "expects 2 argument(s)") { compile("def f(a, b) = a + b\nf(1)") }
  end

  it "rejects malformed programs" do
    expect_raises(Exception, "expected") { compile("let x = 1 x") }
    expect_raises(Exception, "invalid assignment target") { compile("1 = 2") }
    expect_raises(Exception, "reserved function name") { compile("def toy_main() = 1\ntoy_main()") }
  end

  it "survives an O2 pass pipeline" do
    mod = compile(<<-SRC)
      def fib(n) = if n <= 1 then n else fib(n - 1) + fib(n - 2)
      fib(11)
      SRC

    unoptimized = mod.to_s
    triple      = LLVMM.default_target_triple
    machine     = LLVMM::Target.from_triple(triple).create_target_machine(triple, LLVMM.host_cpu_name)
    LLVMM::PassBuilderOptions.new do |options|
      LLVMM.run_passes(mod, "default<O2>", machine, options)
    end
    mod.verify
    mod.to_s.should_not eq(unoptimized)

    jit(mod) { |engine| run(engine).should eq(89) }
  end
end
