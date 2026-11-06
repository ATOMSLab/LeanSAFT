module

import LeanSAFT.Scalar
-- `#guard` runs code at elaboration time, which the module system only allows
-- for `meta`-imported declarations.
meta import LeanSAFT.Scalar

/-!
# Tests for `LeanSAFT.Scalar`

Each formula below is written once over the scalar classes, then
* run at `Float` (`#guard`),
* evaluated exactly at `ℚ` where it is rational, and
* reasoned about at `ℝ`.

The `rfl` examples are the important ones. They check that at `ℝ` and `ℚ`, the
generic text (literals, `^`, decimal constants) elaborates to *exactly* the term
Mathlib would build. A mismatched instance would make them fail.
-/

namespace LeanSAFT.Test

open ScalarLike RationalLike

variable {K : Type}

/-! ## Carnahan–Starling (a `RationalLike` formula) -/

/-- Carnahan–Starling residual Helmholtz energy, `a/(NkT) = (4η − 3η²)/(1 − η)²`. -/
def csAlpha [RationalLike K] (η : K) : K := (4 * η - 3 * η ^ 2) / (1 - η) ^ 2

#guard abs (csAlpha (0.3 : Float) - 1.8979591836734695) < 1e-12
#guard csAlpha (3 / 10 : ℚ) == 93 / 49

example (η : ℝ) : csAlpha η = (4 * η - 3 * η ^ 2) / (1 - η) ^ 2 := rfl
example (η : ℚ) : csAlpha η = (4 * η - 3 * η ^ 2) / (1 - η) ^ 2 := rfl

/-- An exact `ℚ` evaluation is the `ℝ` value: a rational certificate transfers. -/
theorem csAlpha_ratCast (q : ℚ) : ((csAlpha q : ℚ) : ℝ) = csAlpha (q : ℝ) := by
  simp [csAlpha]

/-! ## PC-SAFT segment diameter (`exp` and decimal literals) -/

/-- `d = σ (1 − 0.12 exp(−3ε/kT))`. -/
def segmentDiameter [ScalarLike K] (σ εk T : K) : K :=
  σ * (1 - 0.12 * exp (-3 * εk / T))

-- Methane (σ = 3.7039 Å, ε/k = 150.03 K) at 300 K.
#guard
  let d := segmentDiameter (3.7039 : Float) 150.03 300
  3.60 < d && d < 3.61

example (σ εk T : ℝ) :
    segmentDiameter σ εk T = σ * (1 - 0.12 * Real.exp (-3 * εk / T)) := rfl

theorem segmentDiameter_lt {σ εk T : ℝ} (hσ : 0 < σ) : segmentDiameter σ εk T < σ := by
  have h : 0 < (0.12 : ℝ) * Real.exp (-3 * εk / T) := by positivity
  simp only [segmentDiameter, exp_real]
  nlinarith

/-! ## Mie potential prefactor (`rpow`) -/

/-- `C = λr/(λr − λa) · (λr/λa)^(λa/(λr − λa))`, with `λr`, `λa` written `lr`, `la`. -/
def mieC [ScalarLike K] (lr la : K) : K :=
  lr / (lr - la) * rpow (lr / la) (la / (lr - la))

#guard abs (mieC (12 : Float) 6 - 4) < 1e-12

/-- The (12, 6) Mie potential is Lennard-Jones: `C = 4`. -/
theorem mieC_lj : mieC (12 : ℝ) 6 = 4 := by
  norm_num [mieC]

/-! ## Association, 2B scheme (`sqrt`) -/

/-- Site fraction for two sites with coupling `ρΔ > 0`:
`X = (−1 + √(1 + 4ρΔ)) / (2ρΔ)`, the positive root of `X = 1/(1 + ρΔ X)`. -/
def siteFraction2B [ScalarLike K] (ρΔ : K) : K :=
  (-1 + sqrt (1 + 4 * ρΔ)) / (2 * ρΔ)

#guard
  let X := siteFraction2B (1 : Float)
  abs (X - 1 / (1 + X)) < 1e-12

/-! ## Mixtures (`sumFin`) -/

/-- Mean segment number `m̄ = Σᵢ xᵢ mᵢ`. -/
def meanSegment [PolynomialLike K] {n : ℕ} (x m : Fin n → K) : K :=
  sumFin n fun i => x i * m i

#guard abs (meanSegment (n := 2) ![(0.25 : Float), 0.75] ![1, 2] - 1.75) < 1e-12
#guard meanSegment (n := 2) ![(1 / 4 : ℚ), 3 / 4] ![1, 2] == 7 / 4

example {n : ℕ} (x m : Fin n → ℝ) : meanSegment x m = ∑ i, x i * m i :=
  sumFin_eq n _

/-! ## Cube roots and a generic solver (decidable order) -/

#guard cbrt (-8 : Float) == -2

example : realCbrt 8 ^ 3 = 8 := realCbrt_pow_three 8

/-- Bisection on `[lo, hi]` for `n` steps. Generic over the order, so it runs at
`Float` and exactly at `ℚ`. -/
def bisect [RationalLike K] (f : K → K) (lo hi : K) : ℕ → K
  | 0 => (lo + hi) / 2
  | n + 1 =>
    let mid := (lo + hi) / 2
    if f lo * f mid ≤ 0 then bisect f lo mid n else bisect f mid hi n

-- Root of x³ − 2: bisection agrees with `cbrt 2`.
#guard abs (bisect (fun x : Float => x ^ 3 - 2) 1 2 60 - cbrt 2) < 1e-12
#guard
  let r := bisect (fun x : ℚ => x ^ 3 - 2) 1 2 30
  |r ^ 3 - 2| < 1 / 10 ^ 8

end LeanSAFT.Test
