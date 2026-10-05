process SALMON_QUANT {

    tag "${meta.id}"
    label 'process_medium'

    container 'community.wave.seqera.io/library/salmon:2.7.0--74784226202c61b9'

    input:
    tuple val(meta),
          path(reads),
          path(index),
          path(gtf)

    output:
    tuple val(meta),
          path("${meta.id}.salmon"),
          emit: results

    tuple val(meta),
          path("${meta.id}.quant.sf"),
          emit: transcript_quant

    tuple val(meta),
          path("${meta.id}.quant.genes.sf"),
          emit: gene_quant

    tuple val(meta),
          path("${meta.id}.salmon_meta_info.json"),
          emit: meta_info

    tuple val(meta),
          path("${meta.id}.salmon_lib_format_counts.json"),
          emit: lib_format_counts

    path "versions.yml",
         emit: versions

    script:
    def read_list = reads instanceof List
        ? reads
        : [reads]

    if (!(read_list.size() in [1, 2])) {
        error """
        SALMON_QUANT expected 1 or 2 FASTQ files for ${meta.id},
        found ${read_list.size()}
        """
    }

    def expected_single_end =
        read_list.size() == 1

    if (
        meta.containsKey('single_end') &&
        meta.single_end != expected_single_end
    ) {
        error """
        SALMON_QUANT input contract mismatch for ${meta.id}:
        single_end=${meta.single_end},
        but ${read_list.size()} FASTQ file(s) were provided
        """
    }


    /*
     * Salmon's gene-map parser receives an ordinary GTF file.
     * References from REFERENCE_PREPARATION are normally gzipped,
     * so normalise them here.
     */
    def gtf_command = gtf.name.endsWith('.gz')
        ? "gunzip -c ${gtf} > genes.input.gtf"
        : "cp ${gtf} genes.input.gtf"


    def read_args = expected_single_end
        ? "-r \"${read_list[0]}\""
        : "-1 \"${read_list[0]}\" -2 \"${read_list[1]}\""


    """
    ${gtf_command}

    test -s genes.input.gtf

    salmon quant \
        --index "${index}" \
        --libType A \
        ${read_args} \
        --geneMap genes.input.gtf \
        --validateMappings \
        --threads ${task.cpus} \
        --output "${meta.id}.salmon"

    test -s "${meta.id}.salmon/quant.sf"
    test -s "${meta.id}.salmon/quant.genes.sf"

    cp \
        "${meta.id}.salmon/quant.sf" \
        "${meta.id}.quant.sf"

    cp \
        "${meta.id}.salmon/quant.genes.sf" \
        "${meta.id}.quant.genes.sf"

    test -s "${meta.id}.quant.sf"
    test -s "${meta.id}.quant.genes.sf"

    if [ -f "${meta.id}.salmon/aux_info/meta_info.json" ]; then
        cp \
            "${meta.id}.salmon/aux_info/meta_info.json" \
            "${meta.id}.salmon_meta_info.json"
    else
        printf '{}\\n' \
            > "${meta.id}.salmon_meta_info.json"
    fi

    if [ -f "${meta.id}.salmon/lib_format_counts.json" ]; then
        cp \
            "${meta.id}.salmon/lib_format_counts.json" \
            "${meta.id}.salmon_lib_format_counts.json"
    else
        printf '{}\\n' \
            > "${meta.id}.salmon_lib_format_counts.json"
    fi

    printf '"%s":\\n    salmon: "%s"\\n' \
        "${task.process}" \
        "\$(salmon --version | sed 's/^salmon //')" \
        > versions.yml
    """

    stub:
    def read_list = reads instanceof List
        ? reads
        : [reads]

    if (!(read_list.size() in [1, 2])) {
        error """
        SALMON_QUANT expected 1 or 2 FASTQ files for ${meta.id},
        found ${read_list.size()}
        """
    }

    def expected_single_end =
        read_list.size() == 1

    if (
        meta.containsKey('single_end') &&
        meta.single_end != expected_single_end
    ) {
        error """
        SALMON_QUANT input contract mismatch for ${meta.id}:
        single_end=${meta.single_end},
        but ${read_list.size()} FASTQ file(s) were provided
        """
    }

    """
    mkdir -p "${meta.id}.salmon/aux_info"

    cat > "${meta.id}.salmon/quant.sf" <<'EOF'
Name\tLength\tEffectiveLength\tTPM\tNumReads
ENSTUB000001\t100\t80\t1000000.0\t10.0
EOF

    cat > "${meta.id}.salmon/quant.genes.sf" <<'EOF'
Name\tLength\tEffectiveLength\tTPM\tNumReads
GENESTUB000001\t100\t80\t1000000.0\t10.0
EOF

    printf '{"stub": true}\\n' \
        > "${meta.id}.salmon/aux_info/meta_info.json"

    printf '{"stub": true}\\n' \
        > "${meta.id}.salmon/lib_format_counts.json"

    cp \
        "${meta.id}.salmon/quant.sf" \
        "${meta.id}.quant.sf"

    cp \
        "${meta.id}.salmon/quant.genes.sf" \
        "${meta.id}.quant.genes.sf"

    cp \
        "${meta.id}.salmon/aux_info/meta_info.json" \
        "${meta.id}.salmon_meta_info.json"

    cp \
        "${meta.id}.salmon/lib_format_counts.json" \
        "${meta.id}.salmon_lib_format_counts.json"

    printf '"%s":\\n    salmon: "2.7.0"\\n' \
        "${task.process}" \
        > versions.yml
    """
}