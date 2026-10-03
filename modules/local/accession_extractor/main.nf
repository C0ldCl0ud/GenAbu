process ACCESSION_EXTRACTOR {

    tag "${paper_text.simpleName}"
    label 'process_low'

    container 'python:3.12-slim'

    publishDir 'results/paper_resolve', mode: 'copy', overwrite: true

    input:
    path paper_text

    output:
    path "${paper_text.simpleName}.accessions.tsv", emit: accessions

    script:
    def output_name = "${paper_text.simpleName}.accessions.tsv"

    """
    python3 "\$(command -v extract_accessions.py)" \
        "${paper_text}" \
        "${output_name}"
    """

    stub:
    """
    printf 'accession\trepository\taccession_type\tsource_file\n' \
        > "${paper_text.simpleName}.accessions.tsv"
    """
}
