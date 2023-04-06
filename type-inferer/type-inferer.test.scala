//test: Test

import org.scalatest.FunSuite
import Parser._
import TypeInferer._

class Test extends FunSuite with CatchErrorSuite {

  test("Type Infer 5") {
    expectType(
      numT
    ) {
      typeOf(NumExt(5), Nil)
    }
  }

  test("Type Infer 5+true throws TypeInferenceException") {
    intercept[TypeInferenceException]{
      typeOf(BinOpExt("+", NumExt(5), TrueExt()), Nil)
    }
  }

  test("Type Infer 3*4") {
    expectType(
      numT
    ) {
      typeOf("(* 3 4)", Nil)
    }
  }

  // // ---

  test("Catch erroneous type inferring behavior") {
    intercept[TypeInferenceException] {
      typeOf("x", Nil)
    }
  }

  test("5") {
    val arg = """5"""
    val exp = numT
    assertResult(exp) {
      typeOf(arg, Nil)
    }
  }

  test("true") {
    val arg = """true"""
    val exp = boolT
    assertResult(exp) {
      typeOf(arg, Nil)
    }
  }

  test("+") {
    val arg = """(lambda (x) (+ x x))"""
    val exp = funT(List(numT), numT)
    assertResult(exp) {
      typeOf(arg, Nil)
    }
  }

  test("num=") {
    val arg = """(lambda (x) (num= x x))"""
    val exp = funT(List(numT), boolT)
    assertResult(exp) {
      typeOf(arg, Nil)
    }
  }

  // // NOTE: gw == good weather

  test("if, gw: num x num -> num") {
    val arg = """(lambda (x y) (if (num= x y) (+ x y) (- x y)))"""
    val exp = funT(List(numT, numT), numT)
    assertResult(exp) {
      typeOf(arg, Nil)
    }
  }

  test("if, bw: type mismatch: num vs bool") {
    val arg = """(lambda (x y) (if (num= x y) (and x y) (- x y)))"""
    intercept[TypeInferenceException] {
      typeOf(arg, Nil)
    }
  }

  test("if, bw: condition must be a boolean") {
    val arg = "(if (+ 0 0) 0 0)"
    intercept[TypeInferenceException] {
      typeOf(arg, Nil)
    }
  }

  test("nil, gw") {
    val arg = """nil"""
    assertResult(true) {
      typeOf(arg, Nil) match {
        case TCon(ListTC(), List(TVar(_))) => true
      }
    }
  }

  test("cons/list, gw, 1") {
    val arg = """(cons 1 nil)"""
    val exp = listT(numT)
    assertResult(exp) {
      typeOf(arg, Nil)
    }
  }

  test("cons/list, gw, 2") {
    val arg = """(cons 1 (cons 2 nil))"""
    val exp = listT(numT)
    assertResult(exp) {
      typeOf(arg, Nil)
    }
  }

  test("applying cons, gw") {
    val arg = """(let ((f (lambda (x) (head x)))) (f (cons 1 nil)))"""
    val exp = numT
    assertResult(exp) {
      typeOf(arg, Nil)
    }
  }

  // // NOTE: source https://cstheory.stackexchange.com/q/22257
  test("occurs check") {
    val arg = "(lambda (x) (x x))"
    intercept[TypeInferenceException] {
      typeOf(arg, Nil)
    }
  }

  test("cons/list, bw") {
    val arg = """(cons true (cons 1 nil))"""
    intercept[TypeInferenceException] {
      typeOf(arg, Nil)
    }
  }

  test("is-nil, gw") {
    val arg = """(lambda (x) (is-nil x))"""
    assertResult(true) {
      typeOf(arg, Nil) match {
        case TCon(FunTC(), List(TCon(ListTC(), List(TVar(_))), boolT)) => true
      }
    }
  }

  test("basic let, 1") {
    val arg = """(let ((x 5)) x)"""
    assertResult(numT) {
      typeOf(arg, Nil)
    }
  }

  test("basic let, 2") {
    val arg = """(let ((x 5) (y true)) y)"""
    assertResult(boolT) {
      typeOf(arg, Nil)
    }
  }

  test("basic let, 3") {
    val arg = """(let ((x 5) (y true)) (+ x y))"""
    intercept[TypeInferenceException] {
      typeOf(arg, Nil)
    }
  }

  test("basic let, 4") {
    val arg = """
      (let ((inc (lambda (y) (+ y 1))))
        (inc (+ 3 4)))"""
    assertResult(numT) {
      typeOf(arg, Nil)
    }
  }

  /* NOTE: not implemented */
  // test("polymorphic let") {
  //   val arg = """
  //     (let ((id (lambda (y) y)))
  //       (if (id true) (id 0) (id 1)))"""
  //   assertResult(numT) {
  //     typeOf(arg, Nil)
  //   }
  // }

  // ---

  /**
   * Helpers
   */

  def typeOf(e: String): Type = TypeInferer.typeOf(parse(e))
  def typeOf(e: String, nv: List[TBind]): Type = TypeInferer.typeOf(parse(e), nv)
  def typeOf(e: ExprExt): Type = TypeInferer.typeOf(e)
  def typeOf(e: ExprExt, nv: List[TBind]): Type = TypeInferer.typeOf(e, nv)

  // Tests whether the actual type is the expected type.
  def expectType(expected: Type)(actual: Type) = {
    assertResult(true) {
      isTrivial(unify(List(TEq(expected, actual)), Nil))
    }
  }

  // Is the list of constraints a list of trivial constraints?
  private def isTrivial(sub: List[TEq]): Boolean =
    sub.count({
      case TEq(TVar(_), TVar(_)) => false
      case _ => true
    }) == 0

}
