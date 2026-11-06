# LeanSAFT
Formally-verified statistical associating fluid theory

## Dependencies

| Dependency | Version | Where it is set |
| --- | --- | --- |
| [Lean 4](https://lean-lang.org) | `v4.35.0` | [`lean-toolchain`](lean-toolchain) |
| [Mathlib](https://github.com/leanprover-community/mathlib4) | `v4.35.0` | [`lakefile.toml`](lakefile.toml) |
| [Physlib](https://github.com/leanprover-community/physlib) | `master` | [`lakefile.toml`](lakefile.toml) |

[`lake-manifest.json`](lake-manifest.json) locks every dependency to an exact
commit, so everyone builds against the same code. That includes the packages
Mathlib pulls in (Batteries, Aesop, Qq, ProofWidgets and others).

These three versions have to match. Physlib is built against one Mathlib
release, and that Mathlib release needs one particular Lean version. See
[Updating dependencies](#updating-dependencies) before you change any of them.

## Installation

You need `git`, `curl`, and about 12 GB of free disk space. Mathlib's
prebuilt files take about 7 GB in the project, plus about 5 GB of downloaded
archives in `~/.cache/mathlib`.

1. **Install elan**, the Lean version manager. It downloads the Lean version
   named in `lean-toolchain` on its own, so you never install Lean yourself.

   ```bash
   curl https://elan.lean-lang.org/elan-init.sh -sSf | sh
   ```

   Restart your shell afterwards, or follow the PATH hint the installer
   prints. On Windows, or for more detail, see
   <https://lean-lang.org/install/>.

2. **Clone the repository.**

   ```bash
   git clone https://github.com/ATOMSLab/LeanSAFT.git
   ```

   ```bash
   cd LeanSAFT
   ```

3. **Download Mathlib's prebuilt files.** Skip this and the next step will
   compile Mathlib from source, which takes hours.

   ```bash
   lake exe cache get
   ```

4. **Build.** This only compiles the Physlib modules LeanSAFT imports, plus
   LeanSAFT itself.

   ```bash
   lake build
   ```

5. **Run the tests.** This builds `LeanSAFTTest`, whose `#guard` checks run
   the example formulas at `Float` and `ℚ`. A failed check fails the build.

   ```bash
   lake test
   ```

6. **Open the folder in an editor.** Use VS Code with the
   [Lean 4 extension](https://marketplace.visualstudio.com/items?itemName=leanprover.lean4),
   and open the whole `LeanSAFT` folder, not a single file. Open
   [`LeanSAFT/Basic.lean`](LeanSAFT/Basic.lean) and the infoview should show
   the `#check` results with no errors.

## Writing equation-of-state code

Write each formula once, over a scalar type `K`, using the classes in
[`LeanSAFT/Scalar.lean`](LeanSAFT/Scalar.lean):

| Class | Adds | Instances |
| --- | --- | --- |
| `PolynomialLike` | `+ - *`, literals, `x ^ n` | `ℚ`, `ℝ`, `Float` |
| `RationalLike` | `/`, negation, decimals, order, `abs`, `isFinite` | `ℚ`, `ℝ`, `Float` |
| `ScalarLike` | `sqrt`, `cbrt`, `exp`, `log`, `rpow`, `cos`, `arccos`, `pi` | `ℝ`, `Float` |

The same definition runs at `Float`, can be evaluated exactly at `ℚ` when it
is rational, and is proved about at `ℝ`. At `ℝ` it unfolds to plain Mathlib
terms, so `simp`, `ring` and `positivity` work on it directly.
[`LeanSAFTTest/Scalar.lean`](LeanSAFTTest/Scalar.lean) has worked examples:
Carnahan–Starling, the PC-SAFT segment diameter, the Mie prefactor, 2B
association, and mixture sums.

## Updating dependencies

Lean, Mathlib and Physlib must be updated together:

1. Look up the Mathlib tag in Physlib's
   [`lakefile.toml`](https://github.com/leanprover-community/physlib/blob/master/lakefile.toml)
   and the Lean version in its
   [`lean-toolchain`](https://github.com/leanprover-community/physlib/blob/master/lean-toolchain).
2. Put that Lean version in `lean-toolchain` and that Mathlib tag in
   `lakefile.toml`.
3. Re-resolve the dependencies, fetch the new Mathlib files, and rebuild:

   ```bash
   lake update
   ```

   ```bash
   lake exe cache get
   ```

   ```bash
   lake build
   ```

4. Commit `lean-toolchain`, `lakefile.toml` and `lake-manifest.json` together.
