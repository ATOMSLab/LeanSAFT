module

public import LeanSAFT.Scalar

/-!
# Schema for model-selector input files

Lean types mirroring the JSON input files in `Input/`. `Input/json2lean.lean` turns such a JSON
file into a `.lean` file that builds a `ModelSelectorInput` and proves it `WellFormed`; compiling
that file is what checks the JSON. Three layers of checks run, all at compile time:

1. **Shape.** An unknown key, a missing key, a number where a string belongs, or an enum value
   not listed below is a type error in the generated structure instance.
2. **Consistency.** The proof fields of `ModelSelectorInput` (one density and one mole-fraction
   row per state point, one mole fraction per component, at least one component) are auto-params.
   The generated instance leaves them out, so Lean discharges each by `simp`, which only counts
   list entries, and names the one that fails. They need no arithmetic on the scalars, so they
   are proved once, at every `K`.
3. **Values.** `ModelSelectorInput.WellFormed` collects the constraints that need an ordered
   field: positive temperatures and densities, positive segment parameters, mole fractions in
   `[0, 1]` that sum to one. The generated file proves it for the `ℝ` reading with
   `check_wellFormed`, where `norm_num` compares the decimal literals exactly.

The types are polymorphic in the scalar type `K`, as in `LeanSAFT.Scalar`. The generated file
defines its input once, over `[RationalLike K]`, so the same literals are `Float`s when the
input is fed to an equation of state (`input Float`) and real numbers in the theorems about it
(`input ℝ`). Decimal literals are kept exactly: `2.002 : ℝ` is the rational 2002/1000, not a
binary float, which is what lets `norm_num` decide the value constraints.

Field names are the JSON keys, verbatim, so the converter needs no renaming table. Units are in
the key names (`sigmaA` is σ in Å, `T_K` is T in K, and so on).
-/

@[expose] public section

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
  deriving DecidableEq, Repr

/-- Which polar contribution a component carries. -/
inductive PolarType where
  | none
  deriving DecidableEq, Repr

/-- Polar parameters of a component. -/
structure Polar (K : Type) where
  /-- Which polar term applies. -/
  type : PolarType
  /-- Dipole moment μ, in C·m. -/
  muCm : K
  /-- Quadrupole moment Q, in C·m². -/
  QCm2 : K
  /-- Fraction of segments that carry the polar moment. -/
  xp : K
  deriving Repr

/-- Pure-component parameters of one species. -/
structure Component (K : Type) where
  /-- Name of the species. -/
  name : String
  /-- Number of segments per molecule. -/
  m : K
  /-- Segment diameter σ, in Å. -/
  sigmaA : K
  /-- Dispersion energy over Boltzmann's constant ε/k_B, in K. -/
  epsilonK : K
  /-- Molar mass, in g/mol. -/
  Mw : K
  /-- Polar parameters. -/
  polar : Polar K
  deriving Repr

/-- The thermodynamic model: an equation of state and the components it is applied to. -/
structure Model (K : Type) where
  /-- Equation-of-state options. -/
  eos_options : EosOptions
  /-- The components of the mixture, in the order used by the mole-fraction rows. -/
  components : List (Component K)
  deriving Repr

/-- A property to compute at each state point. -/
inductive Property where
  | eos_interface
  | pressure
  | response_properties
  deriving DecidableEq, Repr

/-- A complete model-selector input: a model and a list of state points, with the consistency
conditions between them as proof fields. Each proof field defaults to `by simp`, which decides
it by counting list entries, so an instance that gives only the data fields is accepted exactly
when the conditions hold. -/
structure ModelSelectorInput (K : Type) where
  /-- The thermodynamic model. -/
  model : Model K
  /-- Temperature of each state point, in K. -/
  T_K : List K
  /-- Molar density of each state point, in mol/m³. -/
  rho_mol_m3 : List K
  /-- Mole fractions: one row per state point, one entry per component. -/
  X : List (List K)
  /-- The properties to compute. -/
  properties : List Property
  /-- The mixture has at least one component. -/
  components_nonempty : 0 < model.components.length := by simp
  /-- One density per state point. -/
  rho_length : rho_mol_m3.length = T_K.length := by simp
  /-- One mole-fraction row per state point. -/
  X_length : X.length = T_K.length := by simp
  /-- One mole fraction per component, in every row. -/
  X_row_length : ∀ row ∈ X, row.length = model.components.length := by simp

/-- The constraints on the *values* of an input. They need an ordered field, so they are stated
for the `ℝ` reading; the generated files prove them with `check_wellFormed`.

The mole fractions of a row must sum to one exactly, as rationals: `[0.3, 0.7]` is accepted,
three copies of `0.333` are not. -/
structure ModelSelectorInput.WellFormed (input : ModelSelectorInput ℝ) : Prop where
  /-- Every temperature is positive. -/
  T_pos : ∀ T ∈ input.T_K, 0 < T
  /-- Every density is positive. -/
  rho_pos : ∀ ρ ∈ input.rho_mol_m3, 0 < ρ
  /-- Every mole fraction is in `[0, 1]`. -/
  X_unit : ∀ row ∈ input.X, ∀ x ∈ row, 0 ≤ x ∧ x ≤ 1
  /-- The mole fractions of each state point sum to one. -/
  X_sum : ∀ row ∈ input.X, row.sum = 1
  /-- Every component has a positive number of segments. -/
  m_pos : ∀ c ∈ input.model.components, 0 < c.m
  /-- Every segment diameter is positive. -/
  sigmaA_pos : ∀ c ∈ input.model.components, 0 < c.sigmaA
  /-- Every dispersion energy is positive. -/
  epsilonK_pos : ∀ c ∈ input.model.components, 0 < c.epsilonK
  /-- Every molar mass is positive. -/
  Mw_pos : ∀ c ∈ input.model.components, 0 < c.Mw
  /-- Dipole and quadrupole moments are magnitudes. -/
  polar_nonneg : ∀ c ∈ input.model.components, 0 ≤ c.polar.muCm ∧ 0 ≤ c.polar.QCm2
  /-- The polar segment fraction is a fraction. -/
  xp_unit : ∀ c ∈ input.model.components, 0 ≤ c.polar.xp ∧ c.polar.xp ≤ 1

/-- Proves `input.WellFormed` once `input` has been unfolded to its literals, as in the generated
files: split the structure into its constraints, let `simp` enumerate the lists, and let
`norm_num` decide each inequality and sum on the exact decimals. A failing constraint is left
as an unsolved goal `False` tagged with the constraint's name, such as `case T_pos`. -/
macro "check_wellFormed" : tactic => `(tactic| (constructor <;> norm_num))

end LeanSAFT.Input
