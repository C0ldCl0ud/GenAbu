process SALMON_INDEX {

    tag "${reference.id} (${reference.assembly})"
    label 'process_medium'

    container 'community.wave.seqera.io/library/salmon:2.7.0--74784226202c61b9'

    input:
    tuple val(reference),
          path(transcript_fasta),
          path(genome_fasta)

    output:
    tuple val(reference),
          path("salmon_index"),
          emit: index

    path "versions.yml",
         emit: versions

    script:
    /*
     * Salmon receives an uncompressed gentrome:
     *
     *   transcripts
     *   +
     *   complete genome used as decoys
     *
     * Fixed local filenames make handling compressed and uncompressed
     * input identical.
     */
    def transcript_command = transcript_fasta.name.endsWith('.gz')
        ? "gunzip -c ${transcript_fasta} > transcripts.input.fa"
        : "cp ${transcript_fasta} transcripts.input.fa"

    def genome_command = genome_fasta.name.endsWith('.gz')
        ? "gunzip -c ${genome_fasta} > genome.input.fa"
        : "cp ${genome_fasta} genome.input.fa"

    """
    ${transcript_command}

    ${genome_command}

    test -s transcripts.input.fa
    test -s genome.input.fa

    grep '^>' genome.input.fa \
        | sed 's/^>//' \
        | cut -d ' ' -f 1 \
        | cut -f 1 \
        > decoys.txt

    test -s decoys.txt

    cat \
        transcripts.input.fa \
        genome.input.fa \
        > gentrome.fa

    test -s gentrome.fa

    salmon index \
        --threads ${task.cpus} \
        --transcripts gentrome.fa \
        --decoys decoys.txt \
        --kmerLen 31 \
        --index salmon_index

    test -d salmon_index
    test -s salmon_index/info.json

    printf '"%s":\\n    salmon: "%s"\\n' \
        "${task.process}" \
        "\$(salmon --version | sed 's/^salmon //')" \
        > versions.yml
    """

    stub:
    """
    mkdir -p salmon_index

    printf '{"stub": true}\\n' \
        > salmon_index/info.json

    touch salmon_index/refseq.bin
    touch salmon_index/refseq_offsets.json
    touch salmon_index/duplicate_clusters.tsv
    touch salmon_index/index.ctab
    touch salmon_index/index.ectab
    touch salmon_index/index.refinfo
    touch salmon_index/index.ssi
    touch salmon_index/index.ssi.mphf
    touch salmon_index/index.tct
    touch salmon_index/index.tdct

    printf '"%s":\\n    salmon: "2.7.0"\\n' \
        "${task.process}" \
        > versions.yml
    """
}