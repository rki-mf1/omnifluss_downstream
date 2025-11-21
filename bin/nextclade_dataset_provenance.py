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


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--meta", help="sample meta map")
    parser.add_argument("--nextclade_csv", help="Nextclade csv output file")
    parser.add_argument("--json", help="pathogen.json file from Nextclade dataset")
    parser.add_argument("-v", "--version", action="version", version="%(prog)s 1.0.0")

    args = parser.parse_args()

    internal_dataset_id = args.meta
    dataset = get_nextclade_dataset_version(args.json)

    df_provenance = get_sample_ids(args.nextclade_csv)

    df_provenance["nextclade_dataset_tag"] = dataset["tag"]
    df_provenance["nextclade_dataset_name"] = dataset["name"]
    df_provenance["nextclade_dataset_shortcut"] = dataset["shortcut"]

    df_provenance["internal_dataset_id"] = internal_dataset_id
    df_provenance.to_csv(
        f"{internal_dataset_id}_nextclade_dataset_provenance.tsv", sep="\t", index=False
    )


if __name__ == "__main__":
    main()
