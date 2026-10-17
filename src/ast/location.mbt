///|
/// The span of an expression. A `Pipeline` has no span of its own: it runs
/// from the start of its first expression to the end of its last one, as
/// `UntypedExpr::location` does in the compiler.
pub fn Expr::location(self : Expr) -> @span.SrcSpan {
  match self {
    Int(location~, ..)
    | Float(location~, ..)
    | String(location~, ..)
    | Block(location~, ..)
    | Var(location~, ..)
    | Fn(location~, ..)
    | List(location~, ..)
    | Call(location~, ..)
    | BinOp(location~, ..)
    | Case(location~, ..)
    | FieldAccess(location~, ..)
    | Tuple(location~, ..)
    | TupleIndex(location~, ..)
    | Todo(location~, ..)
    | Panic(location~, ..)
    | Echo(location~, ..)
    | BitArray(location~, ..)
    | RecordUpdate(location~, ..)
    | NegateBool(location~, ..)
    | NegateInt(location~, ..) => location
    Pipeline(expressions~) => {
      let first = for expr = expressions[0] {
        match expr {
          Pipeline(expressions~) => continue expressions[0]
          other => break other.location().start
        }
      }
      let last = for expr = expressions[expressions.length() - 1] {
        match expr {
          Pipeline(expressions~) =>
            continue expressions[expressions.length() - 1]
          other => break other.location().end
        }
      }
      @span.SrcSpan::from_compiler(first, last).unwrap()
    }
  }
}

///|
/// The span of a pattern. A `BitArraySize` pattern has its size's span; an
/// `Assign` (`pattern as name`) runs from its inner pattern's start to the
/// name's end (its `location` field is the name's span), as
/// `Pattern::location` does in the compiler.
pub fn Pattern::location(self : Pattern) -> @span.SrcSpan {
  match self {
    Assign(location~, pattern~, ..) => {
      let start = for current = pattern {
        match current {
          Assign(pattern~, ..) => continue pattern
          other => break other.location().start
        }
      }
      @span.SrcSpan::from_compiler(start, location.end).unwrap()
    }
    Int(location~, ..)
    | Float(location~, ..)
    | String(location~, ..)
    | Variable(location~, ..)
    | Discard(location~, ..)
    | List(location~, ..)
    | Constructor(location~, ..)
    | Tuple(location~, ..)
    | BitArray(location~, ..)
    | StringPrefix(location~, ..) => location
    BitArraySize(size) => size.location()
  }
}

///|
/// Return the byte span of a bit array size expression.
pub fn BitArraySize::location(self : BitArraySize) -> @span.SrcSpan {
  match self {
    Int(location~, ..)
    | Variable(location~, ..)
    | BinaryOperator(location~, ..)
    | Block(location~, ..) => location
  }
}

///|
/// Return the byte span of a type annotation.
pub fn TypeAst::location(self : TypeAst) -> @span.SrcSpan {
  match self {
    Constructor(c) => c.location
    Fn(f) => f.location
    Var(v) => v.location
    Tuple(t) => t.location
    Hole(h) => h.location
  }
}

///|
/// Return the byte span of a constant.
pub fn Constant::location(self : Constant) -> @span.SrcSpan {
  match self {
    Int(location~, ..)
    | Float(location~, ..)
    | String(location~, ..)
    | Tuple(location~, ..)
    | List(location~, ..)
    | Record(location~, ..)
    | RecordUpdate(location~, ..)
    | BitArray(location~, ..)
    | Var(location~, ..)
    | BinaryOperator(location~, ..)
    | Todo(location~, ..) => location
  }
}

///|
/// The span of a clause guard. A `FieldAccess` has no span field: it runs
/// from the start of its container to the end of its label, as
/// `ClauseGuard::location` does in the compiler.
pub fn ClauseGuard::location(self : ClauseGuard) -> @span.SrcSpan {
  match self {
    Block(location~, ..)
    | BinaryOperator(location~, ..)
    | Not(location~, ..)
    | Var(location~, ..)
    | TupleIndex(location~, ..) => location
    FieldAccess(label_location~, container~, ..) => {
      let start = for current = container {
        match current {
          FieldAccess(container~, ..) => continue container
          other => break other.location().start
        }
      }
      @span.SrcSpan::from_compiler(start, label_location.end).unwrap()
    }
    Constant(c) => c.location()
  }
}

///|
/// Return the byte span of a statement.
/// An expression statement uses the expression's span.
pub fn Statement::location(self : Statement) -> @span.SrcSpan {
  match self {
    Expression(e) => e.location()
    Assignment(a) => a.location
    Use(u) => u.location
    Assert(a) => a.location
  }
}

///|
/// The span of a definition: the compiler's `location` field, which for a
/// function or custom type covers the head only (`end_position` ends the
/// body).
pub fn Definition::location(self : Definition) -> @span.SrcSpan {
  match self {
    Function(f) => f.location
    TypeAlias(t) => t.location
    CustomType(c) => c.location
    Import(i) => i.location
    ModuleConstant(c) => c.location
  }
}
