process TRANSCRIPTOME_GENERATE {

    tag "${reference.id} (${reference.assembly})"
    label 'process_medium'

    container 'quay.io/biocontainers/gffread:0.12.7--hdcf5f25_4'

    publishDir {
        transcript_cache_dir
    },
        mode: 'copy',
        overwrite: true,
        pattern: 'transcripts.fa.gz'

    input:
    tuple val(reference),
          path(genome_fasta),
          path(gtf),
          val(transcript_cache_dir)

    output:
    tuple val(reference),
          path("transcripts.fa.gz"),
          emit: transcript_fasta

    path "versions.yml",
         emit: versions

    script:
    def genome_command = genome_fasta.name.endsWith('.gz')
        ? "gunzip -c ${genome_fasta} > genome.input.fa"
        : "cp ${genome_fasta} genome.input.fa"

    def gtf_command = gtf.name.endsWith('.gz')
        ? "gunzip -c ${gtf} > genes.input.gtf"
        : "cp ${gtf} genes.input.gtf"

    """
    ${genome_command}

    ${gtf_command}

    gffread \
        genes.input.gtf \
        -g genome.input.fa \
        -w transcripts.fa

    test -s transcripts.fa

    gzip -c transcripts.fa \
        > transcripts.fa.gz

    test -s transcripts.fa.gz
    gzip -t transcripts.fa.gz

    printf '"%s":\\n    gffread: "%s"\\n' \
        "${task.process}" \
        "\$(gffread --version 2>&1 | head -1)" \
        > versions.yml
    """

    stub:
    """
    printf '>ENSTUB000001\\nACGTACGT\\n' \
        | gzip -c \
        > transcripts.fa.gz

    printf '"%s":\\n    gffread: "0.12.7"\\n' \
        "${task.process}" \
        > versions.yml
    """
}