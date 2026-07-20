#!/usr/bin/env python

import argparse
import json
import pandas as pd


def get_nextclade_dataset_version(json_path):
    with open(json_path, "r") as f:
        data = json.load(f)

    tag = data.get("version").get("tag")
    name = data.get("attributes").get("name")
    ref_name = data.get("attributes").get("reference name")
    if "shortcuts" in data and len(data.get("shortcuts")) > 0:
        shortcut = data.get("shortcuts")[0]
    else:
        shortcut = None
    return {"tag": tag, "name": name, "shortcut": shortcut, "reference name": ref_name}


def append_versions_to_nextclade_output(nextclade_csv, dataset):
    df = pd.read_csv(nextclade_csv, sep=";")
    df["nextclade.dataset.tag"] = dataset["tag"]
    df["nextclade.dataset.name"] = dataset["name"]
    df["nextclade.dataset.shortcut"] = dataset["shortcut"]
    df["nextclade.dataset.reference.name"] = dataset["reference name"]
    return df


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--meta", help="sample meta map")
    parser.add_argument("--nextclade_csv", help="Nextclade csv output file")
    parser.add_argument("--json", help="pathogen.json file from Nextclade dataset")
    parser.add_argument("-v", "--version", action="version", version="%(prog)s 1.0.0")

    args = parser.parse_args()

    internal_dataset_id = args.meta
    dataset = get_nextclade_dataset_version(args.json)

    df_provenance = append_versions_to_nextclade_output(
        args.nextclade_csv,
        dataset,
    )

    df_provenance["omnifluss.dataset_id"] = internal_dataset_id
    df_provenance.to_csv(
        f"{internal_dataset_id}_with_dataset_provenance.tsv", sep="\t", index=False
    )
    # Prepare a reduced provenance file for MultiQC
    # Nextclade output might have different columns depending on the dataset and pathogen
    df_provenance_mqc = df_provenance[
        [
            "seqName",
            "index",
            "clade",
            "qc.overallStatus",
            "qc.missingData.status",
            "qc.mixedSites.status",
            "nextclade.dataset.tag",
            "nextclade.dataset.name",
            "nextclade.dataset.shortcut",
            "nextclade.dataset.reference.name",
            "omnifluss.dataset_id",
        ]
    ].copy()
    df_provenance_mqc.rename(
        columns={
            "seqName": "sample",
            "index": "nextclade.index",
            "clade": "nextclade.clade",
            "qc.overallStatus": "nextclade.qc.overallStatus",
            "qc.missingData.status": "nextclade.qc.missingData.status",
            "qc.mixedSites.status": "nextclade.qc.mixedSites.status",
        },
        inplace=True,
    )
    df_provenance_mqc.to_csv(
        f"{internal_dataset_id}_nextclade_dataset_provenance.tsv", sep="\t", index=False
    )


if __name__ == "__main__":
    main()
