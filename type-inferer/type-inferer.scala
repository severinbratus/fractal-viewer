import Untyped._

case class NotImplementedException() extends RuntimeException
case class TypeInferenceExceptionConcrete(s: String) extends TypeInferenceException(s)

object TypeInferer {
  type TEnvironment = List[TBind]
  type TSubstitution = List[TEq]

  def typeOf(expr: ExprExt): Type = typeOf(expr, Nil)

  def typeOf(expr: ExprExt, env: TEnvironment): Type = {
    val v = freshTVar()
    val cs = generate(expr, v, env)
    val subs = unify(cs, Nil)
    lookup(subs, v)
  }

  def generate(expr: ExprExt, t_expr: Type, tenv: TEnvironment): List[TEq] = {
    // t_expr is the type expected by the caller.
    // actType the type inferred from the expr
    val (actType, retVal) = helper(expr, t_expr, tenv)
    if (t_expr equals actType) {
      retVal
    } else {
      TEq(t_expr, actType) :: retVal
    }
  }

  def helper(expr: ExprExt, t_expr: Type, tenv: TEnvironment): (Type, List[TEq]) = expr match {
    case BinOpExt(s: String,  l: ExprExt, r: ExprExt)     => s match {
      case "+" | "*" | "-" => {
        val actType = numT
        val retVal = generate(l, numT, tenv) ::: generate(r, numT, tenv)
        (actType, retVal)
      }
      case "and" | "or" => {
        val actType = boolT
        val retVal = generate(l, boolT, tenv) ::: generate(r, boolT, tenv)
        (actType, retVal)
      }
      case "num=" | "num>" | "num<" => {
        val actType = boolT
        val retVal = generate(l, numT, tenv) ::: generate(r, numT, tenv)
        (actType, retVal)
      }
      case "cons" => {
        val tvar = freshTVar()
        val actType = listT(tvar)
        val retVal = generate(l, tvar, tenv) ::: generate(r, listT(tvar), tenv)
        (actType, retVal)
      }
    }
    case UnOpExt (s: String,  e: ExprExt)                 => s match {
      case "-" => {
        val actType = numT
        val retVal = generate(e, numT, tenv)
        (actType, retVal)
      }
      case "not" => {
        val actType = boolT
        val retVal = generate(e, boolT, tenv)
        (actType, retVal)
      }
      case "head" => {
        // This tvar may be redundant (?)
        // val tvar = freshTVar()
        val actType = t_expr
        val retVal = generate(e, listT(t_expr), tenv)
        (actType, retVal)
      }
      case "tail" => {
        // Expected return type of tail is a list,
        // and we expect the arg to be of the same type
        val tvar = freshTVar()
        val actType = listT(tvar)
        val retVal = generate(e, listT(tvar), tenv)
        (actType, retVal)
      }
      case "is-nil" => {
        // Expected return type: boolean.
        // Expected type of the arg: a list with unknown element type
        // thus a fresh tvar is generated to account for this,
        // without putting it into the environment.
        val tvar = freshTVar()
        val actType = boolT
        val retVal = generate(e, listT(tvar), tenv)
        (actType, retVal)
      }
    }
    case IfExt   (c: ExprExt, t: ExprExt, e: ExprExt)     => {
      val retVal = generate(c, boolT, tenv) ::: generate(t, t_expr, tenv) ::: generate(e, t_expr, tenv)
      val actType = t_expr
      (actType, retVal)
    }
    case LetExt  (binds: List[LetBindExt], body: ExprExt) => {
      // Make a tvar for every bind
      val tbinds = binds.map(bind => TBind(bind.name, freshTVar()))
      val teqs = binds.zip(tbinds).flatMap({ case (bind, tbind) => generate(bind.value, tbind.ty, tenv) })
      // We do not know what the actual type of the body is,
      // but it is expected to be of type `t_expr`.
      val retVal = teqs ::: generate(body, t_expr, tbinds ::: tenv)
      val actType = t_expr
      (actType, retVal)
    }
    case FdExt   (params: List[String], body: ExprExt)    => {
      // Make a var for the body type
      val bodyType = freshTVar()
      // Make vars for each param, and bind them in the tenv
      val tbinds = params.map(param => TBind(param, freshTVar()))
      // The actual type is a function from tvars to a tvar
      val actType = funT(tbinds.map(tbind => tbind.ty), bodyType)
      val retVal = generate(body, bodyType, tbinds ::: tenv)
      (actType, retVal)
    }
    case AppExt  (f: ExprExt, args: List[ExprExt])        => {
      val tvars = args.map(arg => freshTVar())
      val tbinds = args.zip(tvars).flatMap({case (arg, tvar) => generate(arg, tvar, tenv)})
      // The expected type is the return type of f
      val actType = t_expr
      val retVal = tbinds ::: generate(f, funT(tvars, t_expr), tenv)
      (actType, retVal)
    }
    case IdExt   (c: String)                              => {
      // Look up the type for the identifier in the tenv
      val actType = tenv.find(tbind => tbind.name == c) match {
        case Some(tbind : TBind) => tbind.ty : Type
        case None => throw new TypeInferenceExceptionConcrete(s"Identifier type not bound: $c")
      }
      val retVal = List()
      (actType, retVal)
    }
    case NumExt  (num: Int)                               => {
      val retVal = List()
      val actType = numT
      (actType, retVal)
    }
    case TrueExt() | FalseExt()                           => {
      val retVal = List()
      val actType = boolT
      (actType, retVal)
    }
    case NilExt()                                         => {
      val retVal = List()
      val actType = listT(freshTVar)
      (actType, retVal)
    }
  }

  def unify(cs: List[TEq], sub: TSubstitution): TSubstitution = cs match {
    case Nil => sub
    case head :: tail => {
      val l = head.lty
      val r = head.rty
      (l, r) match {
        case (TVar(x), TVar(y)) if (x == y) => {
          // Move on, redundant constraint
          unify(cs.tail, sub)
        }
        case (lvar@TVar(_), _) => {
          // Replace l with r both in the stack and substitution
          unify(replace(lvar, r, cs.tail), extendReplace(lvar, r, sub))
        }
        case (_, rvar@TVar(_)) => {
          // Replace r with l ...
          unify(replace(rvar, l, cs.tail), extendReplace(rvar, l, sub))
        }
        case (lcon@TCon(_, _), rcon@TCon(_, _)) => {
          // If concrete types could match, push constraints on fields onto the stack
          if (lcon.con.equals(rcon.con) && lcon.fields.size == rcon.fields.size) {
            val csNew = lcon.fields.zip(rcon.fields).map({case (lf, rf) => TEq(lf, rf)})
            unify(csNew ::: cs.tail, sub)
          } else {
            throw new TypeInferenceExceptionConcrete(f"Type mismatch: l=${prettyprintType(l)} r=${prettyprintType(r)}")
          }
        }
      }
    }
  }

  /**
    * "We expect this to perform the occurs test and, if it fails
    * (i.e., there is no circularity), extends the substituion and
    * replaces all existing instances of the first term with the
    * second in the substitution."
    */
  def extendReplace(l: TVar, r: Type, sub: TSubstitution): TSubstitution = {
    val result = TEq(l, r) :: replace(l, r, sub)
    if (occursCheck(result)) {
      throw new TypeInferenceExceptionConcrete("Occurs check failed")
    } else {
      result
    }
  }

  def occursCheck(result: TSubstitution): Boolean = {
    result.exists(teq => (teq.lty, teq.rty) match {
      case (l: TVar, r: Type) => occurs(l, r)
    })
  }

  /**
    * Check if l occurs in r, recursively.
    */
  def occurs(l: TVar, r: Type): Boolean = {
    r match {
      case rvar@TVar(_) => {
        rvar equals l
      }
      case TCon(_, fields: List[Type]) => {
        fields.exists(field => occurs(l, field))
      }
    }
  }

  /**
    * Replace l with r in sub
    */
  def replace(l: TVar, r: Type, sub: TSubstitution): TSubstitution = {
    sub.map((teq : TEq) => {
      TEq(replace(l, r, teq.lty), replace(l, r, teq.rty))
    })
  }

  /**
    * Replace l with r in t
    */
  def replace(l: TVar, r: Type, t: Type): Type = t match {
    case tvar@TVar(_) => {
      if (l equals tvar) {
        r
      } else {
        tvar
      }
    }
    case TCon(con: TConstructor, fields: List[Type]) => {
      TCon(con, fields.map(replace(l, r, _)))
    }
  }

  def lookup(sub: TSubstitution, v: TVar): Type = {
    sub.find(teq => teq.lty == v) match {
      case Some(teq) => teq.rty
      case None => v
    }
  }

  var currentVarIndex = 0
  def freshTVar(): TVar = {
    currentVarIndex += 1
    TVar("t" + currentVarIndex)
  }

  val numT: Type = TCon(NumTC(), Nil)
  val boolT: Type = TCon(BoolTC(), Nil)
  def funT(argTys: List[Type], retTy: Type): Type = TCon(FunTC(), argTys ::: List(retTy))
  def listT(elemType: Type): Type = TCon(ListTC(), List(elemType))

  def prettyprintType(t: Type): String = t match {
    case TCon(NumTC(), Nil)      => "Num"
    case TCon(BoolTC(), Nil)     => "Bool"
    case TCon(ListTC(), List(ty)) => "(List " + prettyprintType(ty) + ")"
    case TCon(FunTC(), args)     => "((" + args.take(args.size - 1).map(prettyprintType).mkString(", ") + ") -> " + prettyprintType(args.last) + ")"
    case TVar(x)                 => x
    case _                       => "?"
  }

  def prettyprintCs(cs: List[TEq]) = {
    println("{")
    cs.foreach(teq => {
      println(s"  ${prettyprintType(teq.lty)} == ${prettyprintType(teq.rty)}")
    })
    println("}")
  }
}

// The code below is used for grading.
// DO NOT EDIT.

object TypeChecker {
  case class InternalException(msg: String) extends TypeException(msg)

  def ty2comparable(t: Type): Type = t match {
    case TVar(x)     => CTVar(x)
    case TCon(f, cs) => CTCon(f, cs)
    case t =>
      throw InternalException("Expected a TVar or TCon as return type, but got: " + t)
  }

  def typeOf(expr: ExprExt): Type = typeOf(expr, Nil)
  def typeOf(expr: ExprExt, nv: List[TBind]): Type = ty2comparable(TypeInferer.typeOf(expr, nv))
}
