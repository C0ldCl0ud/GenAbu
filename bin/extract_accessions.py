#!/usr/bin/env python3
"""Extract supported public sequencing-data accessions from plain text."""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


ACCESSION_PATTERN = re.compile(
    r"(?<![A-Z0-9])"
    r"(?:GSE[0-9]+|(?:SRP|ERP|DRP)[0-9]+|PRJ(?:NA|EB|DB)[0-9]+|"
    r"(?:SRR|ERR|DRR)[0-9]+)"
    r"(?![A-Z0-9])",
    re.IGNORECASE,
)


def classify(accession: str) -> tuple[str, str]:
    """Return the repository and accession type for a normalized accession."""
    if accession.startswith("GSE"):
        return "GEO", "series"
    if accession.startswith("SRP"):
        return "SRA", "study"
    if accession.startswith("ERP"):
        return "ENA", "study"
    if accession.startswith("DRP"):
        return "DRA", "study"
    if accession.startswith("SRR"):
        return "SRA", "run"
    if accession.startswith("ERR"):
        return "ENA", "run"
    if accession.startswith("DRR"):
        return "DRA", "run"
    if accession.startswith(("PRJNA", "PRJEB", "PRJDB")):
        return "BioProject", "project"

    raise ValueError(f"Unsupported accession: {accession}")


def extract_accessions(text: str) -> list[str]:
    """Extract, normalize, deduplicate, and sort supported accessions."""
    return sorted({match.group(0).upper() for match in ACCESSION_PATTERN.finditer(text)})


def write_accessions(input_path: Path, output_path: Path) -> None:
    """Extract accessions from input_path and write a tab-separated table."""
    text = input_path.read_text(encoding="utf-8", errors="replace")
    accessions = extract_accessions(text)

    with output_path.open("w", encoding="utf-8", newline="") as output_file:
        writer = csv.writer(output_file, delimiter="\t", lineterminator="\n")
        writer.writerow(
            ["accession", "repository", "accession_type", "source_file"]
        )

        for accession in accessions:
            repository, accession_type = classify(accession)
            writer.writerow(
                [accession, repository, accession_type, input_path.name]
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract supported public sequencing-data accessions."
    )
    parser.add_argument("input", type=Path, help="UTF-8 paper text file")
    parser.add_argument("output", type=Path, help="Output TSV file")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    write_accessions(args.input, args.output)


if __name__ == "__main__":
    main()
