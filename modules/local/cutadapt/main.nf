process CUTADAPT {

    tag "${meta.id}"
    label 'process_medium'

    container 'quay.io/biocontainers/cutadapt:5.2--py311haab0aaa_0'

    input:
    tuple val(meta), path(reads)
    val adapters
    val quality_cutoff
    val minimum_length

    output:
    tuple val(meta), path("${meta.id}*.trimmed.fastq.gz"), emit: reads
    tuple val(meta), path("${meta.id}.cutadapt.json"),     emit: report
    tuple val(meta), path("${meta.id}.cutadapt.log"),      emit: log
    path "versions.yml",                                   emit: versions

    script:
    def read_list = reads instanceof List ? reads : [reads]

    if (!(read_list.size() in [1, 2])) {
        error "CUTADAPT expected 1 or 2 FASTQ files for ${meta.id}, found ${read_list.size()}"
    }

    def expected_single_end = read_list.size() == 1

    if (
        meta.containsKey('single_end') &&
        meta.single_end != expected_single_end
    ) {
        error """
        CUTADAPT input contract mismatch for ${meta.id}:
        single_end=${meta.single_end},
        but ${read_list.size()} FASTQ file(s) were provided
        """
    }

    def adapter_args = []

    if (adapters?.r1) {
        adapter_args << "-a '${adapters.r1}'"
    }

    if (!expected_single_end && adapters?.r2) {
        adapter_args << "-A '${adapters.r2}'"
    }

    def quality_args = quality_cutoff
        ? "--quality-cutoff ${quality_cutoff}"
        : ""

    def length_args = minimum_length
        ? "--minimum-length ${minimum_length}"
        : ""

    def output_args = expected_single_end
        ? "-o \"${meta.id}.trimmed.fastq.gz\""
        : "-o \"${meta.id}_R1.trimmed.fastq.gz\" -p \"${meta.id}_R2.trimmed.fastq.gz\""

    def input_args = read_list
        .collect { read -> "\"${read}\"" }
        .join(" ")

    """
    cutadapt \
        --cores ${task.cpus} \
        ${adapter_args.join(' ')} \
        ${quality_args} \
        ${length_args} \
        --json "${meta.id}.cutadapt.json" \
        ${output_args} \
        ${input_args} \
        > "${meta.id}.cutadapt.log"

    printf '"%s":\\n    cutadapt: "%s"\\n' \
        "${task.process}" \
        "\$(cutadapt --version)" \
        > versions.yml
    """

    stub:
    def read_list = reads instanceof List ? reads : [reads]

    if (!(read_list.size() in [1, 2])) {
        error "CUTADAPT expected 1 or 2 FASTQ files for ${meta.id}, found ${read_list.size()}"
    }

    def expected_single_end = read_list.size() == 1

    if (
        meta.containsKey('single_end') &&
        meta.single_end != expected_single_end
    ) {
        error """
        CUTADAPT input contract mismatch for ${meta.id}:
        single_end=${meta.single_end},
        but ${read_list.size()} FASTQ file(s) were provided
        """
    }

    def output_commands = expected_single_end
        ? """
          printf '' | gzip -c > "${meta.id}.trimmed.fastq.gz"
          """
        : """
          printf '' | gzip -c > "${meta.id}_R1.trimmed.fastq.gz"
          printf '' | gzip -c > "${meta.id}_R2.trimmed.fastq.gz"
          """

    """
    ${output_commands}

    printf '%s\\n' \
        '{"tag":"Cutadapt report","cutadapt_version":"5.2"}' \
        > "${meta.id}.cutadapt.json"

    touch "${meta.id}.cutadapt.log"

    printf '"%s":\\n    cutadapt: "5.2"\\n' \
        "${task.process}" \
        > versions.yml
    """
}