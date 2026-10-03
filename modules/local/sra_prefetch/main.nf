process SRA_PREFETCH {

    tag "${meta.id} (${accession})"

    container 'quay.io/biocontainers/sra-tools:3.2.1--h4304569_1'

    input:
    tuple val(meta), val(accession)

    output:
    tuple val(meta), val(accession), path("${accession}", type: 'dir'), emit: sra

    script:
    """
    prefetch "${accession}" \
        --output-directory "${accession}"
    """

    stub:
    """
    mkdir -p "${accession}"
    touch "${accession}/${accession}.sra"
    """
}