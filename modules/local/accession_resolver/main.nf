process ACCESSION_RESOLVER {

    tag "${accessions.simpleName}"
    label 'process_low'

    container 'community.wave.seqera.io/library/pip_ffq:fdd5a80e518d34b0'

    publishDir 'results/paper_resolve', mode: 'copy', overwrite: true, pattern: '*.tsv'
    publishDir 'results/paper_resolve', mode: 'copy', overwrite: true, pattern: 'versions.yml'
    publishDir 'results', mode: 'copy', overwrite: true, pattern: 'samplesheet.csv'

    input:
    path accessions

    output:
    path "${accessions.baseName}.resolved.tsv", emit: resolved
    path "${accessions.baseName}.unresolved.tsv", emit: unresolved
    path "samplesheet.csv", emit: samplesheet
    path "versions.yml", emit: versions

    script:
    // baseName removes only the final .tsv suffix. For an input named
    // paper.accessions.tsv this deliberately preserves paper.accessions.
    def prefix = accessions.baseName

    """
    python3 "\$(command -v resolve_accessions.py)" \
        --input "${accessions}" \
        --resolved "${prefix}.resolved.tsv" \
        --unresolved "${prefix}.unresolved.tsv" \
        --samplesheet "samplesheet.csv" \
        --fail-if-empty

    printf '"%s":\n    ffq: "%s"\n    accession_resolver: "%s"\n' \
        "${task.process}" \
        "\$(ffq --version | awk '{print \$NF}')" \
        "\$(resolve_accessions.py --version)" \
        > versions.yml
    """

    stub:
    """
    printf 'accession\trepository\taccession_type\tsource_file\treason\n' \
        > "${accessions.baseName}.unresolved.tsv"

    printf 'source_accession\tsource_file\tresolution_source\tstudy_accession\tsecondary_study_accession\tsample_accession\tsecondary_sample_accession\texperiment_accession\trun_accession\tscientific_name\tlibrary_strategy\tlibrary_source\tlibrary_selection\tlibrary_layout\tfastq_ftp\tfastq_md5\nSRP000001\tpaper.txt\tena\tSRP000001\t\tSAMN000001\tSRS000001\tSRX000001\tSRR000001\tHomo sapiens\tRNA-Seq\tTRANSCRIPTOMIC\tRANDOM\tPAIRED\t\t\n' \
        > "${accessions.baseName}.resolved.tsv"

    printf 'sample,accession\nSRR000001,SRR000001\n' \
        > samplesheet.csv

    printf '"%s":\n    ffq: "0.3.1"\n    accession_resolver: "0.1.0"\n' \
        "${task.process}" \
        > versions.yml
    """
}
