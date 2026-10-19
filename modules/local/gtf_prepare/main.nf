process GTF_PREPARE {
    tag "${reference.id}"
    label 'process_low'
    container 'quay.io/biocontainers/gffread:0.12.7--hdcf5f25_4'

    input:
    tuple val(reference), path(gtf)

    output:
    tuple val(reference), path('genes.input.gtf'), emit: gtf

    script:
    def command = gtf.name.endsWith('.gz') ? 'gzip -dc' : 'cat'
    """
    ${command} "${gtf}" > genes.input.gtf
    test -s genes.input.gtf
    """

    stub:
    """
    printf 'chr1\\tGenAbu\\tgene\\t1\\t8\\t.\\t+\\t.\\tgene_id "GENESTUB000001";\\n' > genes.input.gtf
    """
}
