module

public import Mathlib.Analysis.SpecialFunctions.Log.Basic
public import Physlib.Thermodynamics.IdealGas.Basic

/-!
# LeanSAFT: toolchain smoke test

Checks that Mathlib and Physlib both load. Replace with real content.
-/

-- From Physlib: ideal-gas entropy and the adiabatic relation.
#check @entropy
#check @adiabatic_relation_log

-- From Mathlib.
example (x y : ℝ) (hx : 0 < x) (hy : 0 < y) :
    Real.log (x * y) = Real.log x + Real.log y :=
  Real.log_mul hx.ne' hy.ne'
