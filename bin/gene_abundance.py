#!/usr/bin/env python3
import csv
import gzip
import argparse
import os
import re

SALMON_SUFFIX = ".quant.genes.sf"

def open_text(filename):

    if filename.endswith(".gz"):
        return gzip.open(
            filename,
            mode="rt",
            encoding="utf-8"
        )

    return open(
        filename,
        mode="rt",
        encoding="utf-8"
    )

def read_annotated_genes(filename):

    genes = []
    seen = set()

    gene_id_pattern = re.compile(
        r'(?:^|;\s*)gene_id\s+"([^"]+)"'
    )

    with open_text(filename) as handle:

        for line_number, line in enumerate(
            handle,
            start=1
        ):

            if not line.strip():
                continue

            if line.startswith("#"):
                continue

            fields = line.rstrip("\n").split("\t")

            if len(fields) != 9:
                raise RuntimeError(
                    f"{filename}:{line_number}: "
                    "expected 9 GTF columns"
                )

            feature = fields[2]

            if feature != "gene":
                continue

            attributes = fields[8]

            match = gene_id_pattern.search(
                attributes
            )

            if match is None:
                raise RuntimeError(
                    f"{filename}:{line_number}: "
                    "gene feature is missing gene_id"
                )

            gene_id = match.group(1)

            if gene_id in seen:
                continue

            seen.add(
                gene_id
            )

            genes.append(
                gene_id
            )

    if not genes:
        raise RuntimeError(
            f"No annotated genes were found in {filename}"
        )

    return genes

parser = argparse.ArgumentParser()
parser.add_argument('--gtf', required=True)
parser.add_argument('--quant', nargs='+', required=True)
args = parser.parse_args()
gtf_file = args.gtf

annotated_gene_order = read_annotated_genes(
    gtf_file
)

annotated_genes = set(
    annotated_gene_order
)

files = sorted(args.quant)

if not files:
    raise RuntimeError(
        "GENE_ABUNDANCE received no Salmon gene quantification files"
    )

samples = []
data = {}
expected_genes = None

for filename in files:

    basename = os.path.basename(
        filename
    )

    if not basename.endswith(
        SALMON_SUFFIX
    ):
        raise RuntimeError(
            f"Unexpected gene quantification filename: {basename}"
        )

    sample = basename[
        :-len(SALMON_SUFFIX)
    ]

    if not sample:
        raise RuntimeError(
            f"Could not derive sample ID from {basename}"
        )

    if sample in data:
        raise RuntimeError(
            f"Duplicate sample ID: {sample}"
        )

    samples.append(
        sample
    )

    with open(
        filename,
        newline="",
        encoding="utf-8"
    ) as handle:

        reader = csv.DictReader(
            handle,
            delimiter="\t"
        )

        required = {
            "Name",
            "TPM",
            "NumReads"
        }

        columns = set(
            reader.fieldnames or []
        )

        missing = (
            required - columns
        )

        if missing:
            raise RuntimeError(
                f"{basename} is missing required columns: "
                + ", ".join(
                    sorted(missing)
                )
            )

        sample_data = {}

        for row in reader:

            gene_id = row["Name"]

            if not gene_id:
                raise RuntimeError(
                    f"{basename} contains an empty gene ID"
                )

            if gene_id not in annotated_genes:
                continue

            if gene_id in sample_data:
                raise RuntimeError(
                    f"{basename} contains duplicate gene ID: "
                    f"{gene_id}"
                )

            sample_data[gene_id] = {
                "TPM": row["TPM"],
                "NumReads": row["NumReads"]
            }

    current_genes = set(
        sample_data
    )

    if not current_genes:
        raise RuntimeError(
            f"{basename} contains no genes present in "
            "the reference GTF"
        )

    if expected_genes is None:

        expected_genes = current_genes

    elif current_genes != expected_genes:

        missing_genes = (
            expected_genes - current_genes
        )

        extra_genes = (
            current_genes - expected_genes
        )

        details = []

        if missing_genes:
            details.append(
                "missing genes: "
                + ", ".join(
                    sorted(missing_genes)[:10]
                )
            )

        if extra_genes:
            details.append(
                "extra genes: "
                + ", ".join(
                    sorted(extra_genes)[:10]
                )
            )

        raise RuntimeError(
            f"Annotated gene set differs between Salmon outputs "
            f"for {sample}: "
            + "; ".join(details)
        )

    data[sample] = sample_data

gene_order = [
    gene_id
    for gene_id in annotated_gene_order
    if gene_id in expected_genes
]

samples = sorted(
    samples
)

def write_matrix(
    filename,
    value_column
):

    with open(
        filename,
        "w",
        newline="",
        encoding="utf-8"
    ) as handle:

        writer = csv.writer(
            handle,
            delimiter="\t",
            lineterminator="\n"
        )

        writer.writerow(
            ["gene_id"] + samples
        )

        for gene_id in gene_order:

            writer.writerow(
                [gene_id]
                +
                [
                    data[sample][gene_id][value_column]
                    for sample in samples
                ]
            )

write_matrix(
    "gene_counts.tsv",
    "NumReads"
)

write_matrix(
    "gene_abundance.tsv",
    "TPM"
)
