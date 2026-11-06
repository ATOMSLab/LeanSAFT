module

public import Mathlib.Analysis.SpecialFunctions.Pow.Real
public import Mathlib.Analysis.SpecialFunctions.Trigonometric.Inverse
public import Mathlib.Algebra.BigOperators.Fin
public import Batteries.Data.Float.Rat

/-!
# LeanSAFT.Scalar

The scalar interface every equation of state in LeanSAFT is written against.
Write a formula once over `[ScalarLike K]`, run it at `Float`, and prove things
about it at `ℝ`. Both readings come from the same source text, so the program
you run is the one the theorem is about.

Adapted from `LeanCatalyst.Scalar`. Three layers, each a bundle of raw
operations with **no algebraic laws**, because `Float` satisfies none of them:

* `PolynomialLike`: `+`, `-`, `*`, every numeric literal, and `x ^ n` for
  `n : ℕ`. Enough for mixing-rule sums and PC-SAFT's dispersion power series.
* `RationalLike`: adds `-x`, `/`, integer and rational casts, decimal literals
  (`0.12`), a decidable order, `==`, `max`, `min`, `abs`, and a finiteness test.
  Enough for Carnahan–Starling, cubic equations of state, and the comparisons
  that Newton and bisection solvers make. `ℚ` has this layer, so a rational
  expression can also be evaluated exactly.
* `ScalarLike`: adds `sqrt`, `cbrt`, `exp`, `log`, `rpow`, `cos`, `arccos` and
  `π`. These cover temperature-dependent diameters (`exp`), association
  strengths and site fractions (`exp`, `sqrt`), residual Helmholtz energies and
  fugacities (`log`), Mie exponents and alpha functions (`rpow`, `sqrt`),
  packing fractions (`π`), and closed-form cubic roots (`cbrt`, `cos`,
  `arccos`).

The instances are `Float` (what runs), `ℝ` (what the theorems are about, and
noncomputable), and `ℚ` for the bottom two layers. Each type gets exactly one
instance, at its top layer, and the lower layers come from the `extends`
projections, so there is never more than one path to an instance. At `ℝ` and
`ℚ`, every bundled operation *is* Mathlib's instance, so `(3 : K)`, `x ^ 2`,
`x / y` and `0.12` specialise to exactly what Mathlib elaborates, and `simp`,
`ring`, `field_simp` and `positivity` work on them without unfolding.

## Where `ℝ` and `Float` disagree

Mathlib's real functions are total, and IEEE-754 doubles fail loudly. So
outside these domains the two readings give different answers, and a theorem
about the `ℝ` reading says nothing about `Float` there:

| expression        | `ℝ`                           | `Float`        |
| ----------------- | ----------------------------- | -------------- |
| `x / 0`           | `0`                           | `±inf` / `NaN` |
| `sqrt x`, `x < 0` | `0`                           | `NaN`          |
| `log x`, `x ≤ 0`  | `log |x|` (`0` at `0`)        | `NaN` / `-inf` |
| `rpow x y`, `x < 0` | `exp (y log |x|) cos (yπ)`  | `NaN` (non-integer `y`) |
| `arccos x`, `|x| > 1` | clamped to `0` or `π`     | `NaN`          |

Theorems carry the domain hypotheses (`0 < T`, `0 ≤ η < 1`, ...) and running
code checks `isFinite` at its boundaries.
-/

@[expose] public section

namespace LeanSAFT

universe u v

/-! ## The three layers -/

/-- **What a polynomial needs**: `+`, `-`, `*`, numeric literals, and
natural-number powers. With no laws attached, this is an interface for writing
code, not an algebraic structure.

Literals `0` and `1` are bundled directly. Literals `2, 3, …` come from Mathlib's
`instOfNatAtLeastTwo` through the bundled `NatCast`, which is also how Mathlib
elaborates them at `ℝ`, so the two agree definitionally. -/
class PolynomialLike (K : Type u) where
  [addK : Add K]
  [subK : Sub K]
  [mulK : Mul K]
  [zeroK : OfNat K 0]
  [oneK : OfNat K 1]
  [natCastK : NatCast K]
  [powNatK : Pow K ℕ]

-- `reducible` before `instance`: typeclass resolution has to see through the
-- bundle to the operation underneath.
attribute [reducible, instance] PolynomialLike.addK PolynomialLike.subK
  PolynomialLike.mulK PolynomialLike.zeroK PolynomialLike.oneK
  PolynomialLike.natCastK PolynomialLike.powNatK

/-- **What a rational function, and a solver deciding with it, needs**: the
polynomial operations plus negation, division, integer and rational casts,
decimal literals, a decidable order, `==`, `max`, `min`, `abs`, and a finiteness
test. Like `PolynomialLike`, it carries no laws. -/
class RationalLike (K : Type u) extends PolynomialLike K where
  [negK : Neg K]
  [divK : Div K]
  [intCastK : IntCast K]
  [ratCastK : RatCast K]
  [ofSciK : OfScientific K]
  [ltK : LT K]
  [leK : LE K]
  [decLtK : DecidableRel (α := K) (· < ·)]
  [decLeK : DecidableRel (α := K) (· ≤ ·)]
  [beqK : BEq K]
  [maxK : Max K]
  [minK : Min K]
  [inhabitedK : Inhabited K]
  /-- `|x|`. -/
  abs : K → K
  /-- Whether `x` is a finite number. Always `true` at `ℝ` and `ℚ`; IEEE's
  test at `Float`. -/
  isFinite : K → Bool

attribute [reducible, instance] RationalLike.negK RationalLike.divK
  RationalLike.intCastK RationalLike.ratCastK RationalLike.ofSciK
  RationalLike.ltK RationalLike.leK RationalLike.decLtK RationalLike.decLeK
  RationalLike.beqK RationalLike.maxK RationalLike.minK RationalLike.inhabitedK

/-- **Everything an equation of state runs on, under one binder**: the rational
operations plus the transcendental functions that SAFT-type and cubic equations
of state use. See the module docstring for which term needs which function, and
for where the `ℝ` and `Float` readings disagree. -/
class ScalarLike (K : Type u) extends RationalLike K where
  /-- `√x`. -/
  sqrt : K → K
  /-- The real cube root `∛x`, defined for negative `x` too (`∛(-8) = -2`).
  Used for the closed-form (Cardano) roots of a cubic equation of state. -/
  cbrt : K → K
  /-- `eˣ`. -/
  exp : K → K
  /-- The natural logarithm. -/
  log : K → K
  /-- `x ^ y` for a scalar exponent (Mie exponents, Twu-type alpha functions). -/
  rpow : K → K → K
  /-- `cos x`. -/
  cos : K → K
  /-- `arccos x`. With `cos` it gives the trigonometric form of a cubic's three
  real roots. -/
  arccos : K → K
  /-- `π`. -/
  pi : K

/-! ## The real cube root

Mathlib has no `Real.cbrt`. `x ^ (1/3 : ℝ)` is wrong for negative `x`, because
`Real.rpow` of a negative base is defined through the complex logarithm. -/

/-- The real cube root: `x ^ (1/3)` for `x ≥ 0`, mirrored for `x < 0`. -/
noncomputable def realCbrt (x : ℝ) : ℝ :=
  if 0 ≤ x then x ^ (1 / 3 : ℝ) else -((-x) ^ (1 / 3 : ℝ))

lemma realCbrt_of_nonneg {x : ℝ} (hx : 0 ≤ x) : realCbrt x = x ^ (1 / 3 : ℝ) :=
  ite_eq_left hx

lemma realCbrt_of_neg {x : ℝ} (hx : x < 0) :
    realCbrt x = -((-x) ^ (1 / 3 : ℝ)) :=
  ite_eq_right (not_le.mpr hx)

private lemma rpow_one_third_pow_three {y : ℝ} (hy : 0 ≤ y) :
    (y ^ (1 / 3 : ℝ)) ^ 3 = y := by
  rw [← Real.rpow_natCast, ← Real.rpow_mul hy]
  norm_num

/-- `realCbrt` really is a cube root: `(∛x)³ = x` for every real `x`. -/
theorem realCbrt_pow_three (x : ℝ) : realCbrt x ^ 3 = x := by
  rcases le_or_gt 0 x with hx | hx
  · rw [realCbrt_of_nonneg hx, rpow_one_third_pow_three hx]
  · rw [realCbrt_of_neg hx, neg_pow, rpow_one_third_pow_three (neg_nonneg.mpr hx.le)]
    norm_num

/-! ## Instances -/

/-- Natural-number power of a `Float` by repeated multiplication. -/
def floatNPow (x : Float) : ℕ → Float
  | 0 => 1
  | n + 1 => floatNPow x n * x

/-- The `Float` reading: IEEE-754 doubles, every operation the hardware's or
libm's. -/
instance : ScalarLike Float where
  natCastK := ⟨Float.ofNat⟩
  powNatK := ⟨floatNPow⟩
  intCastK := ⟨Float.ofInt⟩
  ratCastK := ⟨Rat.toFloat⟩
  abs := Float.abs
  isFinite := Float.isFinite
  sqrt := Float.sqrt
  cbrt := Float.cbrt
  exp := Float.exp
  log := Float.log
  rpow := Float.pow
  cos := Float.cos
  arccos := Float.acos
  pi := 3.141592653589793

/-- The `ℝ` reading, for the theorems. Every bundled operation is Mathlib's own
instance. The order and equality are classical, so this is noncomputable. -/
noncomputable instance : ScalarLike ℝ where
  abs := fun x => |x|
  isFinite := fun _ => true
  sqrt := Real.sqrt
  cbrt := realCbrt
  exp := Real.exp
  log := Real.log
  rpow := fun x y => x ^ y
  cos := Real.cos
  arccos := Real.arccos
  pi := Real.pi

/-- The exact reading: `ℚ` has every rational operation but no square root,
exponential or logarithm, so it stops at `RationalLike`. -/
instance : RationalLike ℚ where
  abs := fun x => |x|
  isFinite := fun _ => true

/-! ## Unfolding at `ℝ` and `ℚ` -/

@[simp] lemma RationalLike.abs_real (x : ℝ) : RationalLike.abs x = |x| := rfl
@[simp] lemma RationalLike.isFinite_real (x : ℝ) : RationalLike.isFinite x = true := rfl
@[simp] lemma ScalarLike.sqrt_real (x : ℝ) : ScalarLike.sqrt x = Real.sqrt x := rfl
@[simp] lemma ScalarLike.cbrt_real (x : ℝ) : ScalarLike.cbrt x = realCbrt x := rfl
@[simp] lemma ScalarLike.exp_real (x : ℝ) : ScalarLike.exp x = Real.exp x := rfl
@[simp] lemma ScalarLike.log_real (x : ℝ) : ScalarLike.log x = Real.log x := rfl
@[simp] lemma ScalarLike.rpow_real (x y : ℝ) : ScalarLike.rpow x y = x ^ y := rfl
@[simp] lemma ScalarLike.cos_real (x : ℝ) : ScalarLike.cos x = Real.cos x := rfl
@[simp] lemma ScalarLike.arccos_real (x : ℝ) : ScalarLike.arccos x = Real.arccos x := rfl
@[simp] lemma ScalarLike.pi_real : (ScalarLike.pi : ℝ) = Real.pi := rfl

@[simp] lemma RationalLike.abs_rat (x : ℚ) : RationalLike.abs x = |x| := rfl
@[simp] lemma RationalLike.isFinite_rat (x : ℚ) : RationalLike.isFinite x = true := rfl

/-! ## Sums

`Finset.sum` needs an `AddCommMonoid`, which `Float` is not, so a sum over the
components of a mixture is written as a fold instead. At `ℝ` it is the usual
`∑`. -/

section Sums

variable {K : Type u} {X : Type v}

/-- `∑ x ∈ l, f x` as a right fold, usable at `Float`. -/
def sumGen [PolynomialLike K] (l : List X) (f : X → K) : K :=
  l.foldr (fun x acc => f x + acc) 0

/-- `∑ i : Fin n, f i`, usable at `Float`. Components of an `n`-component
mixture are indexed by `Fin n`. -/
def sumFin [PolynomialLike K] (n : ℕ) (f : Fin n → K) : K :=
  sumGen (List.finRange n) f

@[simp] lemma sumGen_nil [PolynomialLike K] (f : X → K) : sumGen [] f = 0 := rfl

@[simp] lemma sumGen_cons [PolynomialLike K] (a : X) (l : List X) (f : X → K) :
    sumGen (a :: l) f = f a + sumGen l f := rfl

/-- At `ℝ`, `sumGen` is the list sum. -/
lemma sumGen_eq (l : List X) (f : X → ℝ) : sumGen l f = (l.map f).sum := by
  induction l with
  | nil => rfl
  | cons a l ih => simp [ih]

/-- At `ℝ`, `sumFin` is the `Finset` sum over `Fin n`. -/
lemma sumFin_eq (n : ℕ) (f : Fin n → ℝ) : sumFin n f = ∑ i, f i := by
  rw [sumFin, sumGen_eq, ← List.ofFn_eq_map, List.sum_ofFn]

end Sums

end LeanSAFT
