import Lean.Data.Json

/-!
# json2lean

Converts a model-selector JSON input file into a `.lean` file that builds the same data as a
`LeanSAFT.Input.ModelSelectorInput` (see `Input/Schema.lean`) and proves it `WellFormed`.

The converter does not check the JSON against the schema itself. It writes a Lean term with the
same shape as the JSON, and Lean checks that term when the generated file is compiled:
- a misspelt key, a missing key, a string where a number belongs, or an unknown enum value is a
  type error in the structure instance;
- the consistency conditions of `ModelSelectorInput` (one density and one mole-fraction row per
  state point, and so on) are its auto-param proof fields; the generated instance leaves them
  out, so Lean discharges them by `simp`;
- the value conditions in `ModelSelectorInput.WellFormed` are stated by a theorem this file
  appends, proved by the `check_wellFormed` tactic from the schema.
`Input/Schema.lean` is therefore the only description of the format. This file knows only the
names `ModelSelectorInput`, `WellFormed` and `check_wellFormed`, and which keys hold enums.

The generated definition is polymorphic in the scalar type: `foo (K : Type) [RationalLike K]`,
so `foo Float` is the input an equation of state runs on and `foo ℝ` is the one the theorems are
about, from the same literals.

Usage, from the repository root:

    lean --run Input/json2lean.lean Input/foo.json            # writes Input/foo.lean
    lean --run Input/json2lean.lean Input/foo.json out.lean   # writes out.lean

It needs only Lean core, not Mathlib.

How JSON values are written:
- objects become structure instances `{ key := value, ... }`, with the JSON keys as field names;
- arrays become list literals `[a, b]`;
- numbers are copied exactly as decimal literals (`2.002`, `300.0`), so the schema decides their
  type;
- strings become string literals, except at the key paths in `enumPaths`, where they become
  constructors (`"soft_saft"` becomes `.soft_saft`);
- `null` becomes `none`, and `true`/`false` stay as they are.

Lean's JSON parser does not keep the order of keys, so fields come out in sorted order. Structure
instances do not depend on field order.
-/

open Lean

namespace Json2Lean

/-- Key paths, from the root of the file, whose string values (or arrays of string values) name
constructors of an inductive type in `Input/Schema.lean`. Arrays along a path are transparent:
`["model", "components", "polar", "type"]` is the `type` of every component's `polar`, and no
other key named `type`. The strings there are written as `.name`, so Lean checks them against
the enum. Add a path here when the schema gains a new enum-valued field. -/
def enumPaths : List (List String) :=
  [["model", "eos_options", "eos_model"],
   ["model", "components", "polar", "type"],
   ["properties"]]

/-- Lean keywords that could plausibly appear as JSON keys. They are written as `«key»`. -/
def keywords : List String :=
  ["at", "by", "do", "else", "end", "fun", "from", "have", "if", "in", "let", "match", "open",
    "show", "then", "where", "with", "for", "return", "deriving", "instance", "structure",
    "class", "def", "theorem", "namespace", "section", "import", "Type", "Prop", "Sort"]

/-- `s` as a Lean identifier, wrapped in `«»` unless it is a plain identifier. -/
def ident (s : String) : String :=
  let plain := match s.toList with
    | c :: cs => (c.isAlpha || c == '_') && cs.all (fun c => c.isAlphanum || c == '_' || c == '\'')
    | [] => false
  if plain && !keywords.contains s then s else "«" ++ s ++ "»"

/-- A JSON number as an exact Lean decimal literal: `mantissa * 10^-exponent` with the decimal
point put back, so `2.002` stays `2.002` and `300.0` stays `300.0`. -/
def numLit (n : JsonNumber) : String :=
  let sign := if n.mantissa < 0 then "-" else ""
  let digits := (toString n.mantissa.natAbs).toList
  if n.exponent == 0 then
    sign ++ String.ofList digits
  else
    let padded := List.replicate (n.exponent + 1 - digits.length) '0' ++ digits
    let k := padded.length - n.exponent
    sign ++ String.ofList (padded.take k) ++ "." ++ String.ofList (padded.drop k)

/-- Whether a value is written on one line: anything that contains no object. -/
partial def isFlat : Json → Bool
  | .obj _ => false
  | .arr xs => xs.all isFlat
  | _ => true

/-- `n` spaces. -/
def pad (n : Nat) : String := String.ofList (List.replicate n ' ')

/-- The Lean source for a JSON value found at key path `path` (root first; arrays add nothing to
it), whose first line continues a line indented by `indent`. -/
partial def render (path : List String) (indent : Nat) : Json → String
  | .null => "none"
  | .bool b => toString b
  | .num n => numLit n
  | .str s => if enumPaths.contains path then "." ++ ident s else s.quote
  | .arr xs =>
    if xs.isEmpty then "[]"
    else if xs.all isFlat then
      "[" ++ ", ".intercalate (xs.toList.map (render path indent)) ++ "]"
    else
      let items := xs.toList.map fun x => pad (indent + 2) ++ render path (indent + 2) x
      "[\n" ++ ",\n".intercalate items ++ "\n" ++ pad indent ++ "]"
  | .obj kvs =>
    let fields := kvs.toList.map fun (k, v) =>
      pad (indent + 2) ++ ident k ++ " := " ++ render (path ++ [k]) (indent + 2) v
    if fields.isEmpty then "{}"
    else "{\n" ++ ",\n".intercalate fields ++ "\n" ++ pad indent ++ "}"

/-- The definition name for an input file, before `ident` quoting: its stem in lowerCamelCase,
so `propane_softsaft_model_selector_input.json` gives `propaneSoftsaftModelSelectorInput`. -/
def defName (stem : String) : String :=
  let parts := (stem.splitOn "_").flatMap (·.splitOn "-") |>.filter (· ≠ "")
  let capitalize (s : String) : String := match s.toList with
    | c :: cs => String.ofList (c.toUpper :: cs)
    | [] => s
  match parts with
  | [] => "input"
  | p :: ps =>
    let name := p ++ String.join (ps.map capitalize)
    if name.toList.head?.any Char.isDigit then "input" ++ capitalize name else name

/-- The full contents of the generated `.lean` file. `source` is the input's file name, not its
path: a path can contain a slash followed by a dash, which Lean reads as the start of a nested
comment, breaking the generated docstrings. A file name cannot contain a slash. -/
def generate (source : String) (stem : String) (j : Json) : String :=
  let name := defName stem
  let def_ := ident name
  let thm := ident (name ++ "_wellFormed")
  s!"module

public import Input.Schema

/-!
# {stem}

Generated by `Input/json2lean.lean` from `{source}`.
Do not edit by hand: change the JSON and regenerate.

`{def_} K` is the input at the scalar type `K`:
`{def_} Float` to run an equation of state on, and
`{def_} ℝ` to prove things about.
Compiling this file checks the input against `Input/Schema.lean`;
`{thm}` is the certificate for its value constraints.
-/

@[expose] public section

namespace LeanSAFT.Input

/-- The model-selector input from `{source}`. -/
def {def_} (K : Type) [RationalLike K] : ModelSelectorInput K :=
  {render [] 2 j}

/-- The input from `{source}`
satisfies the value constraints of the schema. -/
theorem {thm} :
    ({def_} ℝ).WellFormed := by
  unfold {def_}
  check_wellFormed

end LeanSAFT.Input
"

end Json2Lean

open Json2Lean in
def main (args : List String) : IO UInt32 := do
  let some (input, output?) := (match args with
      | [i] => some (i, none)
      | [i, o] => some (i, some o)
      | _ => none)
    | IO.eprintln "usage: lean --run Input/json2lean.lean <input.json> [<output.lean>]"; return 1
  let path : System.FilePath := input
  let (some fileName, some stem) := (path.fileName, path.fileStem)
    | IO.eprintln s!"json2lean: cannot read a file name from {input}"; return 1
  let output := output?.getD (path.withExtension "lean").toString
  match Json.parse (← IO.FS.readFile path) with
  | .error e =>
    IO.eprintln s!"json2lean: {input} is not valid JSON: {e}"
    return 1
  | .ok json =>
    IO.FS.writeFile output (generate fileName stem json)
    IO.println s!"json2lean: wrote {output}"
    return 0
