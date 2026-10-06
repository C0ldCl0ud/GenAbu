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

    typed_samplesheets = input.map { samplesheet ->

        def samplesheet_path = samplesheet.toString()
        def input_type = detectInputType(samplesheet_path)

        validateSamplesheetHeader(samplesheet_path)

        log.info("${input_type} as starting point detected.")
        log.info("Input validation successful")

        tuple(input_type, samplesheet_path)
    }

    ch_sra = typed_samplesheets
        .filter { input_type, samplesheet -> input_type == 'sra' }
        .flatMap { input_type, samplesheet ->
            samplesheetToList(
                samplesheet,
                "${projectDir}/assets/schema_input_sra.json"
            )
        }

    ch_fastq = typed_samplesheets
        .filter { input_type, samplesheet -> input_type == 'fastq' }
        .flatMap { input_type, samplesheet ->
            def resolved_sheet =file(samplesheet)
            def content = resolved_sheet.text

            if (content.contains('$projectDir')) {
                resolved_sheet = java.nio.file.Files.createTempFile(
                    'genabu_samplesheet_', '.csv'
                )
                resolved_sheet.toFile().deleteOnExit()
                resolved_sheet.text = content.replace(
                    '${projectDir}',
                    projectDir.toString()
                )
            }
            samplesheetToList(
                samplesheet,
                "${projectDir}/assets/schema_input.json"
            )
        }
        .map { meta, fastq_1, fastq_2 ->

            def reads = fastq_2
                ? [fastq_1, fastq_2]
                : [fastq_1]

            tuple(
                meta + [single_end: !fastq_2],
                reads
            )
        }

    emit:
    sra   = ch_sra
    fastq = ch_fastq
}
