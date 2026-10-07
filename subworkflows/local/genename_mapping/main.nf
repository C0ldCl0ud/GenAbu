process GENENAME_MAPPING_PROCESS {

    tag 'Gene name mapping'
    label 'process_low'

    container 'python:3.13.7-bookworm'

    publishDir 'results',
        mode: 'copy',
        overwrite: true,
        pattern: 'gene_*_mapped.tsv'

    input:
    path gene_names
    path gene_counts
    path gene_abundance


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


    # NCBI gene_info file staged by Nextflow.

    gene_names_file = "${gene_names}"


    # Build gene_id -> gene_name mapping.

    gene_name_mapping = {}


    with open_text(gene_names_file) as handle:

        def clean_lines(handle):

            for line in handle:

                if line.startswith("#tax_id"):

                    yield line.lstrip("#")

                elif not line.startswith("#"):

                    yield line


        reader = csv.DictReader(
            clean_lines(handle),
            delimiter="\t"
        )


        required_columns = {
            "GeneID",
            "Symbol",
            "LocusTag",
            "dbXrefs"
        }


        missing_columns = (
            required_columns
            - set(reader.fieldnames or [])
        )


        if missing_columns:
            raise RuntimeError(
                f"{gene_names_file} is missing required columns: "
                + ", ".join(sorted(missing_columns))
            )


        for row in reader:

            symbol = row["Symbol"].strip()

            if not symbol:
                continue


            # Ensembl IDs are stored in dbXrefs.
            #
            # Example:
            # Ensembl:ENSMUSG00000030359

            dbxrefs = row["dbXrefs"]

            ensembl_match = re.search(
                r'(?:^|\\|)Ensembl:([^|]+)',
                dbxrefs
            )


            if ensembl_match:

                gene_id = ensembl_match.group(1)

                gene_name_mapping[gene_id] = symbol


            # Yeast systematic IDs are stored as LocusTag.

            locus_tag = row["LocusTag"].strip()

            if locus_tag and locus_tag != "-":

                gene_name_mapping[locus_tag] = symbol


    if not gene_name_mapping:
        raise RuntimeError(
            "No gene_id -> gene_name mappings were found in "
            f"{gene_names_file}"
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
                    f"{input_file} must have 'gene_id' "
                    "as first column"
                )


            # Insert gene_name directly after gene_id.

            writer.writerow(
                ["gene_id", "gene_name"]
                + header[1:]
            )


            for row in reader:

                if not row:
                    continue


                gene_id = row[0]


                if gene_id not in gene_name_mapping:

                    raise RuntimeError(
                        f"Gene ID '{gene_id}' has no gene_name "
                        f"mapping in {gene_names_file}"
                    )


                writer.writerow(
                    [
                        gene_id,
                        gene_name_mapping[gene_id]
                    ]
                    + row[1:]
                )


    add_gene_names(
        "gene_counts.tsv",
        "gene_counts_mapped.tsv"
    )


    add_gene_names(
        "gene_abundance.tsv",
        "gene_abundance_mapped.tsv"
    )

    PY

    test -s gene_counts_mapped.tsv
    test -s gene_abundance_mapped.tsv
    """
}


workflow GENENAME_MAPPING {

    take:
    gene_names
    gene_counts
    gene_abundance

    main:

    GENENAME_MAPPING_PROCESS(
        gene_names,
        gene_counts,
        gene_abundance
    )

    emit:
    counts    = GENENAME_MAPPING_PROCESS.out.counts
    abundance = GENENAME_MAPPING_PROCESS.out.abundance
}
