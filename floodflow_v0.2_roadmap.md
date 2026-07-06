# floodflow — Roadmap to v0.2

**From a well-designed teaching release to a validated research tool**

*Prepared in response to the v0.1.0 peer review. Author: Dr George Owusu, Department of Geography and Resource Development, University of Ghana.*

---

## Where v0.1.0 actually stands

Being honest about the starting point matters, because the roadmap only makes sense against it.

**Strengths (already in place).** A coherent ten-stage pipeline on a single `flood_project()` object; pure-R core with optional engines (`terra`, `airGR`, `ranger`, `extRemes`); a 27-page teaching manual with theory boxes, worked equations, and exercises; complete help files with runnable examples and references; and 117 automated tests.

**The real gap.** The 117 tests are overwhelmingly *internal*: they check that the pipeline runs, that objects have the right structure, that stages agree with each other, and that hand-computed formulas match the code. That is necessary but not sufficient. Almost none of them check floodflow's output against an **independent, published, or observed** result. The manual likewise runs on *synthetic* rainfall, not a real gauged record.

In one sentence: **v0.1.0 is internally verified and methodologically transparent, but not yet externally validated.** Every item below serves that single transition.

---

## The five workstreams

Ordered by impact. Workstream 1 is the centerpiece; the others support or extend it.

### 1. Validation study — the centerpiece

The single most important step. Until floodflow's numbers are compared against something outside floodflow, the "research tool" claim is not earned.

**1a. Anchor on one gauged catchment.** Use the Odaw basin, Accra, once real data is in hand:

- Obtain the **real GMet daily rainfall** record for Accra (the manual currently uses a synthetic series). This one dataset unlocks most of the roadmap.
- Obtain an **observed flood** to compare against: a gauged discharge series, a surveyed high-water mark from the June 2026 event, or satellite-derived inundation extent (e.g. Sentinel-1 flood mapping).

**1b. Rebuild Part 1 of the manual on the real record.** Refit the GEV, recompute return levels, and re-examine the June 2026 event as a *genuine same-series* validation rather than a model-vs-reality contrast. This alone materially raises the package's credibility.

**1c. Benchmark against an established model.** Run the same event through one reference tool and tabulate agreement and disagreement:

| floodflow stage | Reference tool | What to compare |
|-----------------|----------------|-----------------|
| routing / depth | HEC-RAS or LISFLOOD-FP | peak depth, inundation extent |
| runoff | HEC-HMS or airGR (calibrated) | hydrograph shape, peak discharge, timing |
| extremes | published GEV fits for Ghana | return levels |

The deliverable is not "floodflow wins" — it is an **honest agreement table** showing where floodflow matches within acceptable error and where it diverges, with the reasons (e.g. the `dynamic` method is a stable 1-D approximation, not full 2-D hydrodynamics).

**1d. Publish it.** Write the validation as a short methods/application paper. This is what converts the reviewer's "has the potential to become" into "is."

### 2. Reproducibility of published results (external-reference tests)

Turn validation into permanent, automated tests so the package cannot silently regress.

- Add a `tests/testthat/test-validation.R` suite whose `expect_equal()` targets are **values from the literature or observations**, not internal hand-calculations. Examples: a GEV return level matching a published Ghana study within tolerance; a Manning discharge matching a textbook worked example; a time-of-concentration matching a Kirpich reference case.
- Bundle small **reference datasets** (see workstream 5) so these tests run anywhere.
- Goal: shift the test balance from ~100% internal to a meaningful fraction external.

### 3. Broader case studies

Move beyond a single basin so the package is not implicitly tuned to Odaw.

- Add 2–3 contrasting catchments: a larger West African basin, a steep headwater catchment, and (ideally) one well-documented international case with open data.
- For each, a short vignette: inputs, floodflow run, comparison to whatever independent result exists.
- This directly addresses the reviewer's "validation against several published flood case studies."

### 4. Performance benchmarking

Establish how floodflow behaves as basins grow, so users know its working envelope.

- Benchmark runtime and memory for increasing raster sizes (e.g. 10², 10⁴, 10⁶ cells) across the spatial stages.
- Document practical limits and where an optional engine (`terra`, `whitebox`) becomes necessary.
- Add a short "Performance" section to the manual or a vignette.

### 5. Bundled real-world datasets

Lower the barrier so users start on real data immediately, not synthetic or `volcano`.

- Ship a small, redistributable **real DEM + rainfall + (if possible) observed flood** for at least one catchment in `inst/extdata/`, with clear licensing.
- Replace or supplement the synthetic manual examples with this bundled real data.
- Mirrors how mature packages (e.g. `terra`'s bundled Luxembourg data) let users run meaningful examples on install.

### 6. Explicit infiltration and sub-daily (event) modelling

Two related additions that share a method (SCS curve-number).

**Spatial water balance.** v0.1.0 exposes the water-balance *components* (rainfall, PET, runoff, runoff ratio) at the lumped level, and the manual reconstructs the partition from them. A full **distributed water balance** — per-cell soil-moisture, actual-evaporation, and storage-change maps evolving through time — is a natural spatial extension. It would run the production-store logic in every cell (like the distributed runoff already in Part 2), producing daily soil-moisture and evaporation rasters alongside the depth maps. This needs the same per-cell care as distributed runoff, plus a mass-conserving store, and should be validated against a point water-balance station before release.

**Explicit infiltration.** v0.1.0 handles infiltration *implicitly*: `flood_runoff()` partitions rainfall into runoff and soil storage through a production store (saturation-excess). There is no infiltration function a user can call and parameterize by soil or land-cover type. Adding an **SCS curve-number** option would let students set infiltration directly (a CN by soil group and land cover), pairing naturally with the existing land-cover roughness table. The CN runoff equation is well-defined, self-contained, and testable against textbook worked examples.

**Sub-daily (event) modelling.** v0.1.0 operates on a **daily** timestep throughout: `flood_runoff()` works in mm/day, and `flood_extremes()` fits GEV to annual maxima of daily rainfall. This is appropriate for regional flood-frequency work but cannot represent the sub-daily intensity that drives urban flash floods — precisely the Accra June 2026 hazard.

Adding a genuine sub-daily/event mode is a real feature, not a relabeling:

- **Routing is already ready.** `flood_route()` accepts a `dt` argument (seconds); hourly routing works today.
- **Runoff needs a second engine.** The daily conceptual store is the wrong physics for a 3-hour storm. A sub-daily mode needs the intensity-aware SCS curve-number method (the same one above) for runoff volume, plus a time-area or unit-hydrograph routing scaled to the event.
- **Extremes need a different frequency method.** Annual-maxima GEV does not apply to single sub-daily events; sub-daily frequency analysis (or an event-based, non-frequency workflow) is required.
- **Validation is mandatory before release.** A naive sub-daily runoff can give backwards peak behaviour (verified during v0.1 scoping). Sub-daily depths must be checked against a gauged sub-daily hydrograph or an established tool (e.g. HEC-HMS, which handles sub-daily natively) before the feature ships.

Estimated effort: the curve-number infiltration is a few hours (self-contained, textbook-verifiable); the sub-daily event engine is a few days to implement, but its validation — and the sub-daily observed data it depends on — is the gating item, as with workstream 1.

---

## Suggested sequence

The workstreams have dependencies; this order front-loads the highest-impact, lowest-cost steps.

**Phase A — data foundation (unlocks everything).**
Obtain real GMet rainfall + one observed flood for Odaw → rebuild manual Part 1 on real data (1a, 1b). Bundle that dataset (5). *Highest impact per unit effort.*

**Phase B — validation core.**
Benchmark Odaw against one reference model; produce the honest agreement table (1c). Convert its results into external-reference tests (2).

**Phase C — breadth and maturity.**
Add 2–3 more case studies (3). Add performance benchmarks (4). Draft the validation paper (1d).

---

## What moves the "maturity" score

The reviewer scored maturity 8.5/10, "mainly because it's an initial release and would benefit from broader validation studies." Concretely, the needle moves most when:

1. The manual runs on **real** rainfall, not synthetic (Phase A).
2. There exists **one** honest, published comparison of floodflow against observations or an established model (Phase B).
3. Tests check **external** reference values, not just internal consistency (Phase B).

Everything else (more basins, performance, more datasets) is valuable breadth, but these three are what change the *category* of the package from "thoughtfully designed teaching release" to "validated research tool."

---

## A note on honest framing

Throughout v0.1.0 the package has been careful to state its limits: the `dynamic` routing method is a stable approximation, not 2-D Saint-Venant; the simple runoff model is a mass-conserving translator, not a calibrated GR4J; HAND-from-DEM is a crude proxy. The roadmap should preserve that honesty. The goal of validation is **not** to claim floodflow matches HEC-RAS everywhere — it is to document precisely where it agrees, where it does not, and why, so researchers can use it with informed confidence. That transparency is itself part of the package's value.
