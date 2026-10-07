process GENENAME_MAPPING_PROCESS {

    tag 'Gene name mapping'
    label 'process_low'

    container 'python:3.13.7-bookworm'

    publishDir 'results',
        mode: 'copy',
        overwrite: true,
        pattern: 'gene_*_mapped.tsv'

    input:
    path gene_counts
    path gene_abundance
    path gtf

    output:
    path "gene_counts_mapped.tsv",
         emit: counts

    path "gene_abundance_mapped.tsv",
         emit: abundance

    script:
    """
    python3 - <<'PY'
    import csv
    import gzip
    import re


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


    # Build gene_id -> gene_name mapping from the GTF.

    gene_name_mapping = {}

    gene_id_pattern = re.compile(
        r'(?:^|;\\s*)gene_id\\s+"([^"]+)"'
    )

    gene_name_pattern = re.compile(
        r'(?:^|;\\s*)gene_name\\s+"([^"]+)"'
    )


    with open_text("${gtf}") as handle:

        for line_number, line in enumerate(
            handle,
            start=1
        ):

            if not line.strip() or line.startswith("#"):
                continue

            fields = line.rstrip("\\n").split("\\t")

            if len(fields) != 9:
                raise RuntimeError(
                    f"{gtf}:{line_number}: "
                    "expected 9 GTF columns"
                )

            # Only gene records are relevant.

            if fields[2] != "gene":
                continue

            attributes = fields[8]

            gene_id_match = gene_id_pattern.search(
                attributes
            )

            if gene_id_match is None:
                continue

            gene_id = gene_id_match.group(1)

            gene_name_match = gene_name_pattern.search(
                attributes
            )

            if gene_name_match is None:
                raise RuntimeError(
                    f"{gtf}:{line_number}: "
                    f"gene '{gene_id}' is missing gene_name"
                )

            gene_name = gene_name_match.group(1)

            if gene_id in gene_name_mapping:
                raise RuntimeError(
                    f"Duplicate gene_id in GTF: {gene_id}"
                )

            gene_name_mapping[gene_id] = gene_name


    if not gene_name_mapping:
        raise RuntimeError(
            "No gene_id -> gene_name mappings were found in the GTF"
        )


    def add_gene_names(input_file, output_file):

        with open(
            input_file,
            "r",
            encoding="utf-8"
        ) as infile, open(
            output_file,
            "w",
            encoding="utf-8",
            newline=""
        ) as outfile:

            reader = csv.reader(
                infile,
                delimiter="\\t"
            )

            writer = csv.writer(
                outfile,
                delimiter="\\t",
                lineterminator="\\n"
            )

            header = next(reader)

            if not header or header[0] != "gene_id":
                raise RuntimeError(
                    f"{input_file} must have 'gene_id' as first column"
                )

            # Insert gene_name directly after gene_id.

            writer.writerow(
                ["gene_id", "gene_name"] + header[1:]
            )


            for row in reader:

                if not row:
                    continue

                gene_id = row[0]

                if gene_id not in gene_name_mapping:
                    raise RuntimeError(
                        f"Gene ID '{gene_id}' has no gene_name "
                        "mapping in the GTF"
                    )

                writer.writerow(
                    [
                        gene_id,
                        gene_name_mapping[gene_id]
                    ]
                    + row[1:]
                )


    add_gene_names(
        "${gene_counts}",
        "gene_counts_mapped.tsv"
    )

    add_gene_names(
        "${gene_abundance}",
        "gene_abundance_mapped.tsv"
    )
    PY

    test -s gene_counts_mapped.tsv
    test -s gene_abundance_mapped.tsv
    """
}

workflow GENENAME_MAPPING {

    take:
    gene_counts
    gene_abundance
    gtf

    main:

    GENENAME_MAPPING_PROCESS(
        gene_counts,
        gene_abundance,
        gtf
    )

    emit:
    counts    = GENENAME_MAPPING_PROCESS.out.counts
    abundance = GENENAME_MAPPING_PROCESS.out.abundance
}