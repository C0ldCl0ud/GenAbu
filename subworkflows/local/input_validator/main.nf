include { validateParameters } from 'plugin/nf-schema'
include { samplesheetToList } from 'plugin/nf-schema'


def detectInputType(input) {

    def header = file(input)
        .readLines()
        .first()
        .split(',')
        .collect { it.trim() }

    def hasFastq = header.contains('fastq_1') || header.contains('fastq_2')
    def hasSra   = header.contains('accession')

    if (hasFastq && hasSra) {
        error "Input samplesheet is ambiguous: contains both FASTQ and SRA columns."
    }

    if (hasSra) {
        return 'sra'
    }

    if (hasFastq) {
        return 'fastq'
    }

    error """
    Could not determine input samplesheet type.

    Expected either:
      sample,fastq_1,fastq_2

    or:
      sample,accession
    """
}


def validateSamplesheetHeader(String samplesheet) {

    def expected_fastq = ['sample', 'fastq_1', 'fastq_2']
    def expected_sra   = ['sample', 'accession']

    def header = file(samplesheet)
        .readLines()
        .first()
        .split(',')
        .collect { it.trim() }

    def has_Fastq_Columns = expected_fastq.every { header.contains(it) }
    def has_Sra_Columns   = expected_sra.every { header.contains(it) }

    if (!has_Fastq_Columns && !has_Sra_Columns) {
        error """
        Invalid samplesheet header.

        Required columns are either:
        sample,fastq_1,fastq_2

        or:
        sample,accession

        Additional columns are allowed.

        Found:
        ${header.join(',')}
        """
    }
}


workflow INPUT_VALIDATOR {

    take:
    input

    main:

    validateParameters()

    input_type = detectInputType(input)

    log.info("${input_type} as starting point detected.")

    validateSamplesheetHeader(input)

    if (input_type == 'sra') {

        ch_sra = Channel.fromList(
            samplesheetToList(
                input,
                "${projectDir}/assets/schema_input_sra.json"
            )
        )
        ch_fastq = Channel.empty()

    } else {

        ch_fastq = Channel.fromList(
            samplesheetToList(
                input,
                "${projectDir}/assets/schema_input.json"
            )
        )
        .map { meta, fastq_1, fastq_2 ->

            def reads = fastq_2
                ? [fastq_1, fastq_2]
                : [fastq_1]

            tuple(
                meta + [single_end: !fastq_2],
                reads
            )
        }
        ch_sra = Channel.empty()
    }

    log.info "Input validation successful"

    emit:
    sra   = ch_sra
    fastq = ch_fastq
}