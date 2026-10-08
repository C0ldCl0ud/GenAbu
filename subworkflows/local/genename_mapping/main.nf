/*
 * Map gene IDs to gene names using two reference sources.
 *
 * Mapping priority:
 *
 *     1. NCBI gene_info file
 *     2. Transcript reference GTF
 *     3. Empty string if no gene name is available
 *
 * The NCBI gene_info file is the primary source because its URL is
 * configured in reference.yaml. The transcript reference is used as
 * a fallback for gene IDs that are not present in the NCBI mapping.
 */
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
    path gtf
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


    /*
     * Open plain-text or gzip-compressed files transparently.
     */
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


    /*
     * ============================================================
     * 1. Build the gene ID -> gene name mapping from NCBI.
     * ============================================================
     *
     * The NCBI gene_info file starts with a header beginning with
     * "#tax_id". The '#' must be removed from this header before
     * passing the file to csv.DictReader.
     *
     * Comment lines beginning with '#' are otherwise ignored.
     */
    gene_names_file = "${gene_names}"

    ncbi_mapping = {}


    with open_text(gene_names_file) as handle:

        def clean_lines(handle):

            for line in handle:

                /*
                 * Keep the NCBI header, but remove its leading '#'.
                 */
                if line.startswith("#tax_id"):

                    yield line[1:]

                /*
                 * Ignore other comment lines.
                 */
                elif not line.startswith("#"):

                    yield line


        reader = csv.DictReader(
            clean_lines(handle),
            delimiter="\\t"
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


            /*
             * Ignore entries without a gene symbol.
             */
            if not symbol:

                continue


            /*
             * ----------------------------------------------------
             * Ensembl IDs stored in dbXrefs.
             * ----------------------------------------------------
             */
            dbxrefs = row["dbXrefs"] or ""


            ensembl_match = re.search(
                r'(?:^|\\|)Ensembl:([^|]+)',
                dbxrefs
            )


            if ensembl_match:

                gene_id = ensembl_match.group(1)

                ncbi_mapping[gene_id] = symbol


            /*
             * ----------------------------------------------------
             * SGD IDs stored in dbXrefs.
             * ----------------------------------------------------
             */
            sgd_match = re.search(
                r'(?:^|\\|)SGD:([^|]+)',
                dbxrefs
            )


            if sgd_match:

                gene_id = sgd_match.group(1)

                ncbi_mapping[gene_id] = symbol


            /*
             * ----------------------------------------------------
             * Locus tags.
             * ----------------------------------------------------
             */
            locus_tag = row["LocusTag"].strip()


            if locus_tag and locus_tag != "-":

                ncbi_mapping[locus_tag] = symbol


    print(
        f"NCBI mappings: {len(ncbi_mapping)}"
    )


    /*
     * ============================================================
     * 2. Build the gene ID -> gene name mapping from the GTF.
     * ============================================================
     *
     * The transcript reference contains attributes such as:
     *
     *     gene_id "YDL246C";
     *     gene_name "SOR2";
     *
     * Therefore the GTF provides a fallback when the gene ID cannot
     * be resolved using the NCBI gene_info file.
     */
    gtf_file = "${gtf}"

    gtf_mapping = {}


    /*
     * Parse key-value pairs from the GTF attributes column.
     */
    def parse_gtf_attributes(attributes):

        result = {}


        for match in re.finditer(
            r'(\\S+)\\s+"([^"]*)"',
            attributes
        ):

            key = match.group(1)
            value = match.group(2)

            result[key] = value


        return result


    with open_text(gtf_file) as handle:

        for line in handle:

            /*
             * Ignore GTF metadata/comment lines.
             */
            if line.startswith("#"):

                continue


            fields = line.rstrip("\\n").split("\\t")


            /*
             * A valid GTF line contains nine columns.
             */
            if len(fields) != 9:

                continue


            attributes = parse_gtf_attributes(
                fields[8]
            )


            gene_id = attributes.get("gene_id")
            gene_name = attributes.get("gene_name")


            /*
             * Keep the first valid gene_name encountered for
             * each gene ID.
             */
            if (
                gene_id
                and gene_name
                and gene_id not in gtf_mapping
            ):

                gtf_mapping[gene_id] = gene_name


    print(
        f"GTF mappings: {len(gtf_mapping)}"
    )


    /*
     * ============================================================
     * 3. Add gene names to the output files.
     * ============================================================
     *
     * Mapping priority:
     *
     *     NCBI
     *       |
     *       v
     *     GTF
     *       |
     *       v
     *     empty string
     */
    def add_gene_names(
        input_file,
        output_file
    ):

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


            /*
             * The input files must contain gene_id as their
             * first column.
             */
            if (
                not header
                or header[0] != "gene_id"
            ):

                raise RuntimeError(
                    f"{input_file} must have 'gene_id' "
                    "as first column"
                )


            /*
             * Insert gene_name directly after gene_id.
             */
            writer.writerow(
                [
                    "gene_id",
                    "gene_name"
                ]
                + header[1:]
            )


            for row in reader:

                if not row:

                    continue


                gene_id = row[0]


                /*
                 * ------------------------------------------------
                 * Priority 1: NCBI
                 * ------------------------------------------------
                 */
                if gene_id in ncbi_mapping:

                    gene_name = ncbi_mapping[gene_id]


                /*
                 * ------------------------------------------------
                 * Priority 2: transcript reference GTF
                 * ------------------------------------------------
                 */
                elif gene_id in gtf_mapping:

                    gene_name = gtf_mapping[gene_id]


                /*
                 * ------------------------------------------------
                 * Priority 3: no available gene name
                 * ------------------------------------------------
                 *
                 * Do not fail the process if no mapping exists.
                 * Instead, leave the gene_name field empty.
                 */
                else:

                    gene_name = ""


                writer.writerow(
                    [
                        gene_id,
                        gene_name
                    ]
                    + row[1:]
                )


    /*
     * Apply the mapping to the gene count table.
     */
    add_gene_names(
        "gene_counts.tsv",
        "gene_counts_mapped.tsv"
    )


    /*
     * Apply the mapping to the gene abundance table.
     */
    add_gene_names(
        "gene_abundance.tsv",
        "gene_abundance_mapped.tsv"
    )


    PY

    /*
     * Make sure both output files exist and are non-empty.
     */
    test -s gene_counts_mapped.tsv
    test -s gene_abundance_mapped.tsv
    """
}


/*
 * Gene name mapping workflow.
 *
 * The GTF is passed in addition to the NCBI gene_info file so that
 * it can be used as a fallback source for gene names.
 */
workflow GENENAME_MAPPING {

    take:
    gene_names
    gtf
    gene_counts
    gene_abundance

    main:

    GENENAME_MAPPING_PROCESS(
        gene_names,
        gtf,
        gene_counts,
        gene_abundance
    )

    emit:
    counts =
        GENENAME_MAPPING_PROCESS.out.counts

    abundance =
        GENENAME_MAPPING_PROCESS.out.abundance
}