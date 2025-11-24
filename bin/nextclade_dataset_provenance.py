#!/usr/bin/env python

import argparse
import json
import pandas as pd


def get_nextclade_dataset_version(json_path):
    with open(json_path, "r") as f:
        data = json.load(f)

    tag = data.get("version").get("tag")
    name = data.get("attributes").get("name")
    if "shortcuts" in data:
        shortcut = data.get("shortcuts")[0]
    else:
        shortcut = None
    return {"tag": tag, "name": name, "shortcut": shortcut}


def get_sample_ids(nextclade_csv):
    df = pd.read_csv(nextclade_csv, sep=";")
    return df[["seqName", "index"]].rename(
        columns={"seqName": "sample", "index": "nextclade_index"}
    )

def append_versions_to_nextclade_output(nextclade_csv, dataset):
    df = pd.read_csv(nextclade_csv, sep=";")
    df["nextclade_dataset_tag"] = dataset["tag"]
    df["nextclade_dataset_name"] = dataset["name"]
    df["nextclade_dataset_shortcut"] = dataset["shortcut"]
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

    df_provenance["internal_dataset_id"] = internal_dataset_id
    df_provenance.to_csv(
        f"{internal_dataset_id}_with_dataset_provenance.tsv", sep="\t", index=False
    )
    df_provenance.rename(columns={"seqName": "sample", "index": "nextclade_index"}, inplace=True)
    df_provenance.to_csv(
        f"{internal_dataset_id}_nextclade_dataset_provenance.tsv", sep="\t", index=False, columns=[
            "sample",
            "nextclade_index",
            "nextclade_dataset_tag",
            "nextclade_dataset_name",
            "nextclade_dataset_shortcut",
            "internal_dataset_id",
        ], 
    )


if __name__ == "__main__":
    main()
