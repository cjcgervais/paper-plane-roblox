# ADR-0001: Constitution Adoption
- **Status:** Accepted
- **Date:** 2025-09-19
- **Context:** EZTrustZone (Roblox Studio: EZTrustZone)
- **Decision Makers:** Project Sentinel Roundtable (dpsk, Nemo, Grok, Qwen, Z, Gemini, GPT)
- **Guardian Seal:** <<TO_BE_FILLED_BY_GUARDIAN_CI>>

## Context
Project Sentinel needs a binding Constitution to anchor EZTZ provenance, Guardian CI gates, Chronicle evidence, and VR11 alignment.

## Decision
Adopt `docs/Constitution.md` as the supreme governance artifact. Immutable by default; changes require a new ADR + Guardian seal. Canonical hash is enforced in CI.

## Consequences
- PRs altering the Constitution without ADR are blocked.
- Chronicle records the adoption as genesis.
- All metrics/scripts trace authority to this Constitution.

## Provenance
- **Repo:** cjcgervais/paper-plane-roblox
- **Commit:** <<TO_BE_FILLED_BY_GUARDIAN_CI>>
- **Chronicle Entry:** chronicle/2025-09-19T-constitution-adoption.json
- **Evidence Hash:** <<TO_BE_FILLED_BY_GUARDIAN_CI>>

## Status
✅ Adopted and sealed.
