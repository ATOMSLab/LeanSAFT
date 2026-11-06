import Mathlib.Basic.Real.Basic

/-!
# Schema for model-selector input files

Lean types mirroring the JSON input files in `Input/`. `Input/json2lean.lean` turns such a JSON
file into a `.lean` file that builds a `ModelSelectorInput`; compiling that file is what checks
the JSON against this schema. An unknown key, a missing key, a number where a string belongs, or
an enum value not listed below is a compile error.

Field names are the JSON keys, verbatim, so the converter needs no renaming table. Numbers are
real numbers, so the decimal literals in the JSON are kept exactly (`2.002 : ℝ` is the rational
2002/1000, not a binary float) and can later be reasoned about with `norm_num`.

The units in the docstrings are read off the key names (`sigmaA` is σ in Å, `T_K` is T in K, and
so on).

Constraints between fields, such as one mole-fraction row per state point that sums to one, are
not part of the types yet.
-/

namespace LeanSAFT.Input

/-- The equation of state to evaluate. Add a constructor for each new model the input
format supports. -/
inductive EosModel where
  | soft_saft
  deriving DecidableEq, Repr

/-- Options selecting the equation of state. -/
structure EosOptions where
  /-- Which SAFT variant to use. -/
  eos_model : EosModel

/-- Which polar contribution a component carries. -/
inductive PolarType where
  | none
  deriving DecidableEq, Repr

/-- Polar parameters of a component. -/
structure Polar where
  /-- Which polar term applies. -/
  type : PolarType
  /-- Dipole moment μ, in C·m. -/
  muCm : ℝ
  /-- Quadrupole moment Q, in C·m². -/
  QCm2 : ℝ
  /-- Fraction of segments that carry the polar moment. -/
  xp : ℝ

/-- Pure-component parameters of one species. -/
structure Component where
  /-- Name of the species. -/
  name : String
  /-- Number of segments per molecule. -/
  m : ℝ
  /-- Segment diameter σ, in Å. -/
  sigmaA : ℝ
  /-- Dispersion energy over Boltzmann's constant ε/k_B, in K. -/
  epsilonK : ℝ
  /-- Molar mass, in g/mol. -/
  Mw : ℝ
  /-- Polar parameters. -/
  polar : Polar

/-- The thermodynamic model: an equation of state and the components it is applied to. -/
structure Model where
  /-- Equation-of-state options. -/
  eos_options : EosOptions
  /-- The components of the mixture, in the order used by the mole-fraction rows. -/
  components : List Component

/-- A property to compute at each state point. -/
inductive Property where
  | eos_interface
  | pressure
  | response_properties
  deriving DecidableEq, Repr

/-- A complete model-selector input: a model and a list of state points. -/
structure ModelSelectorInput where
  /-- The thermodynamic model. -/
  model : Model
  /-- Temperature of each state point, in K. -/
  T_K : List ℝ
  /-- Molar density of each state point, in mol/m³. -/
  rho_mol_m3 : List ℝ
  /-- Mole fractions: one row per state point, one entry per component. -/
  X : List (List ℝ)
  /-- The properties to compute. -/
  properties : List Property

end LeanSAFT.Input
