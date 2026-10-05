process GENE_ABUNDANCE {

    tag 'Gene abundance matrix'
    label 'process_low'

    container 'python:3.13.7-bookworm'

    publishDir 'results',
        mode: 'copy',
        overwrite: true,
        pattern: 'gene_*.tsv'

    input:
    path gene_quant_files

    output:
    path "gene_counts.tsv",
         emit: counts

    path "gene_abundance.tsv",
         emit: abundance

    path "versions.yml",
         emit: versions

    script:
    """
    python3 - <<'PY'
    import csv
    import glob
    import os
    import sys


    SUFFIX = ".quant.genes.sf"


    files = sorted(
        glob.glob(f"*{SUFFIX}")
    )

    if not files:
        raise RuntimeError(
            "GENE_ABUNDANCE received no Salmon gene quantification files"
        )


    samples = []
    data = {}
    gene_order = None
    expected_genes = None


    for filename in files:

        basename = os.path.basename(filename)

        if not basename.endswith(SUFFIX):
            raise RuntimeError(
                f"Unexpected gene quantification filename: {basename}"
            )

        sample = basename[:-len(SUFFIX)]

        if not sample:
            raise RuntimeError(
                f"Could not derive sample ID from {basename}"
            )

        if sample in data:
            raise RuntimeError(
                f"Duplicate sample ID: {sample}"
            )

        samples.append(sample)


        with open(
            filename,
            newline="",
            encoding="utf-8"
        ) as handle:

            reader = csv.DictReader(
                handle,
                delimiter="\\t"
            )

            required = {
                "Name",
                "TPM",
                "NumReads"
            }

            columns = set(
                reader.fieldnames or []
            )

            missing = required - columns

            if missing:
                raise RuntimeError(
                    f"{basename} is missing required columns: "
                    + ", ".join(sorted(missing))
                )


            sample_data = {}
            current_order = []


            for row in reader:

                gene_id = row["Name"]

                if not gene_id:
                    raise RuntimeError(
                        f"{basename} contains an empty gene ID"
                    )

                if gene_id in sample_data:
                    raise RuntimeError(
                        f"{basename} contains duplicate gene ID: {gene_id}"
                    )

                sample_data[gene_id] = {
                    "TPM": row["TPM"],
                    "NumReads": row["NumReads"]
                }

                current_order.append(
                    gene_id
                )


        current_genes = set(
            sample_data
        )


        if expected_genes is None:

            expected_genes = current_genes
            gene_order = current_order

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
                f"Gene set differs between Salmon outputs for {sample}: "
                + "; ".join(details)
            )


        data[sample] = sample_data



     # Sort sample columns so output is deterministic regardless of
     # Nextflow channel scheduling.

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
                delimiter="\\t",
                lineterminator="\\n"
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


     # Salmon estimated counts.
     # These may be fractional because Salmon performs probabilistic
     # assignment of reads.

    write_matrix(
        "gene_counts.tsv",
        "NumReads"
    )



    # TPM = Transcripts Per Million.

    write_matrix(
        "gene_abundance.tsv",
        "TPM"
    )
    PY

    test -s gene_counts.tsv
    test -s gene_abundance.tsv

    printf '"%s":\\n    python: "%s"\\n' \
        "${task.process}" \
        "\$(python3 --version | awk '{print \$2}')" \
        > versions.yml
    """

    stub:
    """
    cat > gene_counts.tsv <<'EOF'
gene_id	sample1
GENESTUB000001	10.0
EOF

    cat > gene_abundance.tsv <<'EOF'
gene_id	sample1
GENESTUB000001	1000000.0
EOF

    printf '"%s":\\n    python: "3.13.7"\\n' \
        "${task.process}" \
        > versions.yml
    """
}