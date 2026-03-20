#!/usr/bin/env python3

import argparse
import pandas as pd


def sort_func_INV_HA(elem):
    # first part
    if elem.startswith("SigPep:"):
        prio = 0
    elif elem.startswith("HA1:"):
        prio = 1
    elif elem.startswith("HA2:"):
        prio = 2
    else:
        prio = None

    # second part
    num_part = int("".join(filter(str.isdigit, elem.split(":")[1])))
    return (prio, num_part)


def sort_func(elem):
    num_part = int("".join(filter(str.isdigit, elem.split(":")[1])))
    return num_part


def create_tbl(ID, nextclade_csv):
    df = pd.read_csv(nextclade_csv, sep=";")

    # aaSubstitutions
    variants = ",".join(df["aaSubstitutions"].dropna().tolist())

    if variants:
        unique_variants = list(set(variants.split(",")))

        # order variants
        if ID.endswith("HA"):
            unique_variants = sorted(unique_variants, key=sort_func_INV_HA)
        else:
            unique_variants = sorted(unique_variants, key=sort_func)
        # unique_variants does not appear to be sorted deterministically
        for variant in unique_variants:
            col_name = f"sub_{variant}"
            df[col_name] = df["aaSubstitutions"].apply(
                lambda x: variant in x if isinstance(x, str) else False
            )
            df.loc[df[col_name], col_name] = (
                variant  # replace all values that are True with the respective variant name
            )

    # aaDeletions
    aaDeletions = ",".join(df["aaDeletions"].dropna().tolist())

    if aaDeletions:
        unique_aaDeletions = list(set(aaDeletions.split(",")))

        # order deletions
        if ID.endswith("HA"):
            unique_aaDeletions = sorted(unique_aaDeletions, key=sort_func_INV_HA)
        else:
            unique_aaDeletions = sorted(unique_aaDeletions, key=sort_func)

        for aaDeletion in unique_aaDeletions:
            col_name = f"del_{aaDeletion}"
            df[col_name] = df["aaDeletions"].apply(
                lambda x: aaDeletion in x if isinstance(x, str) else False
            )
            df.loc[df[col_name], col_name] = (
                aaDeletion  # replace all values that are True with the respective deletion name
            )

    # aaInsertions
    aaInsertions = ",".join(df["aaInsertions"].dropna().tolist())

    if aaInsertions:
        unique_aaInsertions = list(set(aaInsertions.split(",")))

        # order insertions
        if ID.endswith("HA"):
            unique_aaInsertions = sorted(unique_aaInsertions, key=sort_func_INV_HA)
        else:
            unique_aaInsertions = sorted(unique_aaInsertions, key=sort_func)

        for aaInsertion in unique_aaInsertions:
            col_name = f"ins_{aaInsertion}"
            df[col_name] = df["aaInsertions"].apply(
                lambda x: aaInsertion in x if isinstance(x, str) else False
            )
            df.loc[df[col_name], col_name] = (
                variant  # replace all values that are True with the respective variant name
            )

    df.to_csv(f"{ID}_nextclade_adapted.csv", sep=";", index=False)


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("ID", help="used ID")
    parser.add_argument("nextclade_output", help="Nextclade Output")
    parser.add_argument("-v", "--version", action="version", version="%(prog)s 1.0.0")

    args = parser.parse_args()

    create_tbl(args.ID, args.nextclade_output)


if __name__ == "__main__":
    main()
