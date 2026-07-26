#!/usr/bin/env python3

"""
Concatenate FASTA records by their headers and filter based on patterns and X content.

This script processes multiple FASTA files, concatenating sequences with the same header,
filtering out sequences based on exclude patterns and X character content threshold.
"""

import argparse
import logging
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Set


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Concatenate FASTA records by header and filter sequences"
    )
    parser.add_argument(
        "--fastas",
        nargs="+",
        required=True,
        help="Input FASTA files to process",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output concatenated FASTA file",
    )
    parser.add_argument(
        "--exclude_patterns",
        type=str,
        help="Patterns to exclude from headers (space-separated strings, e.g. 'swine sw')",
    )
    parser.add_argument(
        "--x_threshold",
        type=float,
        help="Maximum fraction of X characters allowed",
    )
    parser.add_argument(
        "--line_width",
        type=int,
        default=80,
        help="Width of sequence lines in output (default: 80)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose logging",
    )
    return parser.parse_args()


def setup_logging(verbose: bool) -> None:
    """Configure logging."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        format="%(asctime)s - %(levelname)s - %(message)s",
        level=level,
    )


def read_fasta_file(fasta_path: Path) -> Dict[str, List[str]]:
    """
    Read a FASTA file and return sequences grouped by header.

    Args:
        fasta_path: Path to FASTA file

    Returns:
        Dictionary mapping headers to list of sequences
    """
    sequences_by_header = defaultdict(list)
    current_header = None
    current_seq = []

    logging.debug(f"Reading FASTA file: {fasta_path}")

    with open(fasta_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            if line.startswith(">"):
                # Save previous sequence if exists
                if current_header is not None:
                    sequences_by_header[current_header].append("".join(current_seq))

                # Start new sequence
                current_header = line
                current_seq = []
            else:
                current_seq.append(line)

        # Save last sequence
        if current_header is not None:
            sequences_by_header[current_header].append("".join(current_seq))

    return sequences_by_header


def should_exclude_header(header: str, exclude_patterns: List[str]) -> bool:
    """
    Check if header should be excluded based on patterns.

    Args:
        header: FASTA header line
        exclude_patterns: List of patterns to exclude

    Returns:
        True if header should be excluded, False otherwise
    """
    if not exclude_patterns:
        return False
    return any(pattern in header for pattern in exclude_patterns if pattern)


def calculate_x_fraction(sequence: str) -> float:
    """
    Calculate fraction of X characters in sequence.

    Args:
        sequence: Protein or nucleotide sequence

    Returns:
        Fraction of X characters (0.0 to 1.0)
    """
    if len(sequence) == 0:
        return 0.0
    x_count = sequence.upper().count("X")
    return x_count / len(sequence)


def write_fasta_sequence(
    file_handle, header: str, sequence: str, line_width: int = 80
) -> None:
    """
    Write a FASTA sequence to file with specified line width.

    Args:
        file_handle: Open file handle for writing
        header: FASTA header line (with '>')
        sequence: Sequence to write
        line_width: Maximum characters per line
    """
    file_handle.write(header + "\n")
    for i in range(0, len(sequence), line_width):
        file_handle.write(sequence[i : i + line_width] + "\n")


def process_fasta_files(
    fasta_files: List[str],
    output_path: str,
    exclude_patterns: List[str],
    x_threshold: float,
    line_width: int,
) -> None:
    """
    Process FASTA files: concatenate by header and filter.

    Args:
        fasta_files: List of input FASTA file paths
        output_path: Output file path
        exclude_patterns: Patterns to exclude from headers
        x_threshold: Maximum allowed fraction of X characters
        line_width: Width of sequence lines in output
    """
    # Read all FASTA files and combine sequences by header
    all_sequences_by_header = defaultdict(list)

    for fasta_file in fasta_files:
        sequences = read_fasta_file(Path(fasta_file))
        for header, seqs in sequences.items():
            all_sequences_by_header[header].extend(seqs)

    logging.info(f"Found {len(all_sequences_by_header)} unique headers")

    # Process and write filtered sequences
    stats = {
        "total_headers": len(all_sequences_by_header),
        "excluded_by_pattern": 0,
        "excluded_by_x_threshold": 0,
        "excluded_by_empty": 0,
        "written": 0,
    }

    with open(output_path, "w") as out:
        for header in sorted(all_sequences_by_header.keys()):
            # Check for exclude patterns
            if exclude_patterns:
                if should_exclude_header(header, exclude_patterns):
                    logging.debug(f"Excluding header by pattern: {header}")
                    stats["excluded_by_pattern"] += 1
                    continue

            # Concatenate all sequences for this header
            concatenated_seq = "".join(all_sequences_by_header[header])

            # Filter empty sequences
            if len(concatenated_seq) == 0:
                logging.debug(f"Excluding empty sequence: {header}")
                stats["excluded_by_empty"] += 1
                continue

            # Filter based on X content
            if x_threshold:
                x_fraction = calculate_x_fraction(concatenated_seq)
                if x_fraction >= x_threshold:
                    logging.debug(f"Excluding by X threshold ({x_fraction:.2%}): {header}")
                    stats["excluded_by_x_threshold"] += 1
                    continue

            # Write to output
            write_fasta_sequence(out, header, concatenated_seq, line_width)
            stats["written"] += 1

    # Log statistics
    logging.info(f"Processing complete:")
    logging.info(f"  Total unique headers: {stats['total_headers']}")
    logging.info(f"  Excluded by pattern: {stats['excluded_by_pattern']}")
    logging.info(f"  Excluded by X threshold: {stats['excluded_by_x_threshold']}")
    logging.info(f"  Excluded by empty sequence: {stats['excluded_by_empty']}")
    logging.info(f"  Written to output: {stats['written']}")


def main() -> None:
    """Main entry point."""
    args = parse_args()
    setup_logging(args.verbose)

    logging.info(f"Processing {len(args.fastas)} FASTA file(s)")
    logging.info(
        f"Exclude patterns: {args.exclude_patterns if args.exclude_patterns else 'None'}"
    )
    logging.info(
        f"X threshold: {args.x_threshold if args.x_threshold else 'None'}"
    )

    process_fasta_files(
        fasta_files=args.fastas,
        output_path=args.output,
        exclude_patterns=[p for p in args.exclude_patterns.split()] if args.exclude_patterns else None,
        x_threshold=args.x_threshold,
        line_width=args.line_width,
    )

    logging.info(f"Output written to: {args.output}")


if __name__ == "__main__":
    main()
