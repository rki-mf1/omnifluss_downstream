#!/usr/bin/env python

import argparse
import pandas as pd


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--samplenames",
        help="Expected sample names as common fasta header prefix for segmented genomes, comma separated",
    )
    parser.add_argument("--nextclade_tsv", help="Nextclade csv output file")
    parser.add_argument(
        "--is-influenza", action="store_true", help="Is influenza data?"
    )
    parser.add_argument("-v", "--version", action="version", version="%(prog)s 1.0.0")

    args = parser.parse_args()

    samples = args.samplenames.split(",")

    # Read in all Nextclade TSVs in one dataframe
    df = pd.DataFrame()
    for tsv in args.nextclade_tsv.split(","):
        df_part = pd.read_csv(tsv, sep="\t", header=0)
        df_part = df_part[
            [
                "seqName",
                "clade",
                "qc.overallStatus",
                "nextclade.dataset.name",
            ]
        ]
        df = pd.concat([df, df_part], ignore_index=True)

    # Find rows corresponding to each sample
    # seqName contains a common fasta header prefix for segmented genomes
    # We match based on that
    # sample_tables = []
    for sample in samples:
        df_sample = df[df["seqName"].str.startswith(sample)]
        if not df_sample.empty:
            df_sample.loc[:, "sample"] = sample
            if args.is_influenza:
                # Add a new column with the reference clade extracted from seqName
                # TODO: this is header-specific, may need to be adapted for other data
                df_sample.loc[:, "omnifluss.reference.clade"] = (
                    df_sample["seqName"].str.split("|").str[-2].str.split("_").str[-1]
                )
                all_refs = df_sample["nextclade.dataset.name"].to_list()
                print(all_refs)
                # Influenza B
                if all(ref.startswith("Influenza B") for ref in all_refs):
                    # check is all references are "Influenza B Victoria"
                    if all("Vic" in ref for ref in all_refs):
                        df_sample.loc[:, "omnifluss.potential_reassortant"] = False
                    # check is all references are "Influenza B Yamagata"
                    elif all("Yam" in ref for ref in all_refs):
                        df_sample.loc[:, "omnifluss.potential_reassortant"] = False
                    else:
                        df_sample.loc[:, "omnifluss.potential_reassortant"] = True
                # Influenza A
                elif all(ref.startswith("Influenza A") for ref in all_refs):
                    # check if all subtypes are the same
                    subtypes = [ref.split(" ")[2] for ref in all_refs]
                    if len(set(subtypes)) == 1:
                        df_sample.loc[:, "omnifluss.potential_reassortant"] = False
                    else:
                        df_sample.loc[:, "omnifluss.potential_reassortant"] = True
                else:
                    df_sample.loc[:, "omnifluss.potential_reassortant"] = True
            else:
                df_sample.loc[:, "omnifluss.reference.clade"] = "n/a"
                df_sample.loc[:, "omnifluss.potential_reassortant"] = "n/a"
        else:
            df_sample.loc[0] = ["n/a", "n/a", "n/a", "n/a"]
            df_sample.loc[:, "sample"] = sample
            df_sample.loc[:, "seqName"] = sample
            df_sample.loc[:, "omnifluss.reference.clade"] = "n/a"
            df_sample.loc[:, "omnifluss.potential_reassortant"] = "n/a"
        # Reorder columns
        # sample cannot be first column due to MultiQC
        # MultiQC needs unique values in the first column
        df_sample = df_sample[
            [
                "seqName",
                "sample",
                "omnifluss.reference.clade",
                "nextclade.dataset.name",
                "omnifluss.potential_reassortant",
                "clade",
                "qc.overallStatus",
            ]
        ]
        df_sample = df_sample.rename(columns={
            "seqName": "nextclade.seqName",
            "clade": "nextclade.clade",
            "qc.overallStatus": "nextclade.qc.overallStatus",
        })
        df_sample.to_csv(f"{sample}_types_per_sample.tsv", sep="\t", index=False)


if __name__ == "__main__":
    main()
