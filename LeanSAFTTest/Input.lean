module

import Input.propane_softsaft_model_selector_input
-- `#guard` runs code at elaboration time, which the module system only allows
-- for `meta`-imported declarations.
meta import Input.propane_softsaft_model_selector_input

/-!
# Tests for the generated input files

A generated input is one definition over `[RationalLike K]`. Its `Float`
reading is ordinary data that runs; its `ℝ` reading is what
`..._wellFormed` is about. Both come from the same literals.
-/

namespace LeanSAFT.Test

open LeanSAFT.Input

-- The `Float` reading runs.
#guard (propaneSoftsaftModelSelectorInput Float).T_K == [300.0]
#guard (propaneSoftsaftModelSelectorInput Float).model.components.map (·.name) == ["propane"]
#guard (propaneSoftsaftModelSelectorInput Float).X == [[1.0]]

-- The `ℝ` reading is the one the certificate is about, and its literals are exact.
example : (propaneSoftsaftModelSelectorInput ℝ).model.components.map (·.m) = [2002 / 1000] := by
  norm_num [propaneSoftsaftModelSelectorInput]

example : (propaneSoftsaftModelSelectorInput ℝ).WellFormed :=
  propaneSoftsaftModelSelectorInput_wellFormed

end LeanSAFT.Test
