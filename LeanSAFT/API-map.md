# Statistical associating fluid theory

## Abstract

Statistical associating fluid theory (SAFT) is a molecular equation of state for fluids whose
molecules form chains and bond to one another through short-ranged, highly directional attractions
such as hydrogen bonds. It is formulated as a model for the Helmholtz free energy, split into an
ideal-gas part and a residual part. The residual part is a sum of contributions from a reference
fluid of segments, from the formation of chains out of those segments, and from association
between bonding sites, the last two derived from Wertheim's first-order thermodynamic perturbation
theory. Pressure, chemical potentials and phase equilibria then follow from the free energy by
differentiation. Common variants include the original SAFT, PC-SAFT and SAFT-VR Mie, which differ
chiefly in their choice of reference fluid.

## Content (Alpha)

### Helmholtz free energy decomposition

SAFT models a fluid at fixed temperature, volume and number of molecules, the setting of the
canonical ensemble {1}, whose natural thermodynamic potential is the Helmholtz free energy. [1]
The reduced free energy a = A / (N k_B T) is a sum a = a^ideal + a^seg + a^chain + a^assoc, each
term a function of temperature, density and composition. [TODO]

#### The association term

A molecule of component i carries M_i bonding sites, and site A on component i bonds to site B on
component j with strength Δ^AB_ij. In Wertheim's first-order perturbation theory the association
contribution is a^assoc = Σ_i x_i [Σ_A (ln X^A_i − X^A_i / 2) + M_i / 2], where X^A_i, the
fraction of molecules of component i not bonded at site A, solves the mass-action equations
X^A_i = 1 / (1 + ρ Σ_j x_j Σ_B X^B_j Δ^AB_ij). {2} [TODO] For every positive density and
non-negative bond strengths these equations have a unique solution with each X^A_i in (0, 1].
[TODO]

## Lean References

1. Physlib/StatisticalMechanics/CanonicalEnsemble/Basic.lean — `CanonicalEnsemble.helmholtzFreeEnergy`,
   `CanonicalEnsemble.helmholtzFreeEnergy_def`

## References

1. Canonical ensemble API map — Physlib/StatisticalMechanics/CanonicalEnsemble/API-map.md
2. W. G. Chapman, K. E. Gubbins, G. Jackson and M. Radosz, *New reference equation of state for
   associating liquids*, Ind. Eng. Chem. Res. 29 (1990) 1709–1721,
   https://doi.org/10.1021/ie00104a021
