def normalize_channel(){

}

process FASTERQ_DUMP {

    tag "${meta.id} (${accession})"
    label 'process_medium'

    container 'quay.io/biocontainers/sra-tools:3.4.1--h4304569_0'

    cpus 4

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
    touch "${accession}_1.fastq.gz"
    touch "${accession}_2.fastq.gz"
    """
}