process ACCESSION_RESOLVER {

    tag "${accessions.simpleName}"
    label 'process_low'

    container 'community.wave.seqera.io/library/pip_ffq:fdd5a80e518d34b0'

    input:
    path accessions

    output:
    path "${accessions.baseName}.resolved.tsv", emit: resolved
    path "${accessions.baseName}.unresolved.tsv", emit: unresolved
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
        --fail-if-empty

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ffq: "\$(ffq --version | awk '{print \$NF}')"
        accession_resolver: "\$(resolve_accessions.py --version)"
    END_VERSIONS
    """

    stub:
    """
    printf 'source_accession\tsource_file\tresolution_source\tstudy_accession\tsecondary_study_accession\tsample_accession\tsecondary_sample_accession\texperiment_accession\trun_accession\tscientific_name\tlibrary_strategy\tlibrary_source\tlibrary_selection\tlibrary_layout\tfastq_ftp\tfastq_md5\n' \
        > "${accessions.baseName}.resolved.tsv"

    printf 'accession\trepository\taccession_type\tsource_file\treason\n' \
        > "${accessions.baseName}.unresolved.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ffq: "0.3.1"
        accession_resolver: "0.1.0"
    END_VERSIONS
    """
}
