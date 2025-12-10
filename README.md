# rki-mf1/omnifluss_downstream

## Introduction

**rki-mf1/omnifluss_downstream** is a bioinformatics pipeline that ...


1. Assign to each single fasta sequence a Nextclade dataset ([`nextcalde sort`](https://github.com/nextstrain/nextclade))
2. Clade/lineage assignment, mutation calling and sequence quality checks ([`nextcalde run`](https://github.com/nextstrain/nextclade))
   1. Add Nextclade dataset version information for each fasta file
3. Summarize results ([`MultiQC`](http://multiqc.info/))

... for SARS-CoV-2, influenza virus (A/H1N1, A/H3N2, A/H5Nx and B/Victoria), measles virus and respiratory syncytial virus (RSV).

By default, the latest available Nextclade dataset will be used for the respective sequences.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fasta
AEG588A1,/path/to/fasta/AEG588A1.fasta
```

Each row represents a single or multi fasta file.

> [!NOTE]
> For segmented genomes (currently influenza, `-profile INV`), each line should represent one sample, thus a multi fasta file with all segments of a sample.


Now, you can run the pipeline using:

<!-- TODO nf-core: update the following command to include all required parameters for a minimal example -->

```bash
nextflow run rki-mf1/omnifluss_downstream \
   -profile <docker/singularity/.../institute/PATHOGEN> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

Currently supported pathogen profiles are:

| Profile name | Pathogen                    |
| ------------ | --------------------------- |
| CVD          | SARS-CoV-2                  |
| INV          | Influenza virus             |
| MSV          | Measles virus               |
| RSV          | Respiratory syncytial virus |


> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

## Credits

rki-mf1/omnifluss_downstream was originally written by [Dimitri Ternovoj](https://github.com/DimitriTernovoj).

We thank the following people for their extensive assistance in the development of this pipeline:

- [Marie Lataretu](https://github.com/MarieLataretu/)
- [Thomas Krannich](https://github.com/Krannich479)

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use rki-mf1/omnifluss_downstream for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
