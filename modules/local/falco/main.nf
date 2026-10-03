process FALCO {

    tag "${meta.id}"
    label 'process_low'

    container 'quay.io/biocontainers/falco:2.0.2--h3be2455_0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}*_fastqc_data.txt"),    emit: data
    tuple val(meta), path("${meta.id}*_fastqc_report.html"), emit: html
    tuple val(meta), path("${meta.id}*_summary.txt"),        emit: summary

    script:
    def read_list = reads instanceof List ? reads : [reads]

    if (!(read_list.size() in [1, 2])) {
        error "FALCO expected 1 or 2 FASTQ files for ${meta.id}, found ${read_list.size()}"
    }

    def expected_single_end = read_list.size() == 1

    if (meta.containsKey('single_end') && meta.single_end != expected_single_end) {
        error "FALCO input contract mismatch for ${meta.id}: single_end=${meta.single_end}, but ${read_list.size()} FASTQ file(s) were provided"
    }

    def read_args = read_list
        .collect { read -> "\"${read}\"" }
        .join(" ")

    def move_commands = read_list.withIndex().collect { read, index ->

        def suffix = read_list.size() == 1
            ? ""
            : "_R${index + 1}"

        // Falco 2.x removes .fastq/.fq and optional .gz
        // when naming its per-input output directory.
        def falco_dir = read.name.replaceFirst(/(\.fastq|\.fq)(\.gz)?$/, '')

        """
        mv "falco_out/${falco_dir}/fastqc_data.txt" \
            "${meta.id}${suffix}_fastqc_data.txt"

        mv "falco_out/${falco_dir}/fastqc_report.html" \
            "${meta.id}${suffix}_fastqc_report.html"

        mv "falco_out/${falco_dir}/summary.txt" \
            "${meta.id}${suffix}_summary.txt"
        """
    }.join("\n")

    """
    rm -rf falco_out

    falco \
        -o falco_out \
        -t ${task.cpus} \
        ${read_args}

    ${move_commands}

    rm -rf falco_out
    """

    stub:
    def read_list = reads instanceof List ? reads : [reads]

    if (!(read_list.size() in [1, 2])) {
        error "FALCO expected 1 or 2 FASTQ files for ${meta.id}, found ${read_list.size()}"
    }

    def expected_single_end = read_list.size() == 1

    if (meta.containsKey('single_end') && meta.single_end != expected_single_end) {
        error "FALCO input contract mismatch for ${meta.id}: single_end=${meta.single_end}, but ${read_list.size()} FASTQ file(s) were provided"
    }

    def outputs = read_list.withIndex().collect { read, index ->

        def suffix = read_list.size() == 1
            ? ""
            : "_R${index + 1}"

        """
        touch "${meta.id}${suffix}_fastqc_data.txt"
        touch "${meta.id}${suffix}_fastqc_report.html"
        touch "${meta.id}${suffix}_summary.txt"
        """
    }.join("\n")

    """
    ${outputs}
    """
}