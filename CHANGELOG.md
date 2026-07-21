# rki-mf1/omnifluss_downstream: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## v0.3.0 [2026-07-21]

### `Changed`

- nextclade in- and output is sorted
- all nextclade outputs are published
- nextclade dataset retrieval is not cached anymore to ensure latest datasets are always used 

### `Added`

- added phylogenetic analysis of nextclade's translated fastas
  - samples can be filtered by X content in the translated fasta sequences
  - samples can be filtered by patterns to matching the fasta headers
- monkeypox virus support (`MPV`)

### `Fixed`

- fixed multiqc config for many samples
- fixed `nextclade sort` output path for influenza B
  - output path and nextclade dataset name (`nextstrain/flu/vic`) do not match since we want to use the fixed dataset `2025-09-09--12-13-13Z` (not containing subclade C.3.3) which is not available for dataset `nextstrain/flu/b`
- added upper bound for nextflow version to ensure compatibility
- fixed input handling for IQtree with less than 3 sequences

## v0.2.0 [2026-01-27]

### `Changed`

- nextclade dataset versions can now be specified via a CSV file (`--nextclade_dataset_config`)
  - fixed and pre-defined for INV
  - latest dataset version used for RSV, MSV, CVD
  
### `Added`

- added WGS and N450 nextclade dataset for MSV

## v0.1.0 [2025-12-10]

Initial release of rki-mf1/omnifluss_downstream, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- added nextclade sort
- added nextclade run for INV, RSV, CVD
  - added different datasets
- added summarizing tables
- added (custom) MultiQC report
