include { validateParameters } from 'plugin/nf-schema'

def validateSamplesheetHeader(String samplesheet) {

    def expected = ['sample', 'fastq_1', 'fastq_2']

    def header = new File(samplesheet)
        .readLines()
        .first()
        .split(',')
        .collect { it.trim() }

    if (header != expected) {
        error """
        Invalid samplesheet header.

        Expected:
        sample,fastq_1,fastq_2

        Found:
        ${header.join(',')}
        """
    }
}

workflow {


    validateSamplesheetHeader(params.input)
    validateParameters()

    log.info "Input validation successful"
}