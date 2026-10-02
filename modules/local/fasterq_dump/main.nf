process FASTERQ_DUMP {

    tag "${meta.id} (${accession})"
    label 'process_medium'

    container 'quay.io/biocontainers/sra-tools:3.4.1--h4304569_0'

    input:
    tuple val(meta), val(accession), path(sra_dir)

    output:
    tuple val(meta), path("${accession}*.fastq.gz"), emit: reads

    script:
    """
    mkdir -p tmp

    fasterq-dump "${sra_dir}" \
        --split-files \
        -e ${task.cpus} \
        -t tmp

    gzip *.fastq
    """

    stub:
    """
    if [[ "${meta.stub_single_end ?: false}" == "true" ]]; then
        touch "${accession}.fastq.gz"
    else
        touch "${accession}_1.fastq.gz"
        touch "${accession}_2.fastq.gz"
    fi
    """
}
