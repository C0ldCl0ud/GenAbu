process SRA_PREFETCH {

    tag "${meta.id} (${accession})"

    container 'quay.io/biocontainers/sra-tools:3.4.1--h4304569_0'

    input:
    tuple val(meta), val(accession)

    output:
    tuple val(meta), val(accession), path("${accession}", type: 'dir'), emit: sra

    script:
    """
    prefetch "${accession}" \
        --output-directory "${accession}"

    vdb-validate "${accession}"
    """

    stub:
    """
    mkdir -p "${accession}"
    touch "${accession}/${accession}.sra"
    """
}