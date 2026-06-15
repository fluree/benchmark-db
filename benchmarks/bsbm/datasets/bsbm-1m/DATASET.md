# Dataset: BSBM 1M (scale point pc=2785)

The smallest BSBM scale — the canonical "1M" point — used here to **validate the
end-to-end harness** (generate → load into Fluree → drive the query mix → parse
results) before spending box-time at 100M / 200M.

## Generated, not downloaded

BSBM data comes from a **deterministic generator** (`bsbmtools-0.2/generate`).
Given the same toolkit version and flags, the output N-Triples are byte-identical
on any machine — there is no random seed in generation. So reproducibility is
pinned by:

| Pin | Value |
|-----|-------|
| Toolkit | bsbmtools v0.2 (`setup-bsbmtools.sh`, sha256 `40f5e59b…`) |
| Scale | `-pc 2785` (product count) |
| Flags | `-fc` (forward-chained) `-s nt` (N-Triples) `-ud` (also emit update dataset) |
| Triples (`dataset.nt`) | **724,101** |
| SHA-256 (`dataset.nt`) | `0eca9f19829be6390700196c5de4fe6e3d0610e1cd09d7f780de6526a95a48c8` |
| Update dataset (`dataset_update.nt`) | 276,211 triples |

`fetch-data.sh` ensures the toolkit is present, runs the generator at `pc=2785`,
and **re-checks** the triple count + SHA-256 against the pins above (warns on
drift). Fluree's importer accepts `.nt` natively (`--from dataset.nt`), so no
format conversion is needed.

## What's in it

A small e-commerce graph (forward-chained):

- 4,745 product features; 60 producers, 2,785 products (5 product types);
- 29 vendors with 55,700 offers;
- 4 rating sites, 1,417 reviewers, 27,850 reviews.

The `td/` directory also holds the test-driver **parameter pools** (`*.dat`) —
the value ranges the driver samples to instantiate each query template. They are
read via `testdriver -idir td` and must match the scale that generated them.

## How it's loaded

- **Fluree:** `fluree create bsbm --from td/dataset.nt` (then `fluree server start`).
- Update use case additionally uses `td/dataset_update.nt` via the driver's
  `-udataset` flag, sent as form-encoded SPARQL Update to `…/v1/fluree/update/bsbm:main`.

## Comparability

- `pc=2785` is the scale **point** every BSBM paper cites as "1M"; the *exact*
  triple count depends on toolkit version and `-fc`, so we record the measured
  **724,101** rather than the round label. Engine-vs-engine on one box is valid;
  absolute QMpH is not comparable across different toolkit versions or scales.
- At 1M, BSBM's Q5 (similar-products) does **not** dominate the mix the way it can
  at 100M / 200M, so the standard mix is fine here (the reduced-mix question is a
  large-scale concern — see the 100m/200m datasets when added).

## Sources

- BSBM: <http://wbsg.informatik.uni-mannheim.de/bizer/berlinsparqlbenchmark/>
- Toolkit (pinned): SourceForge `bsbmtools/bsbmtools-0.2/bsbmtools-v0.2.zip`
