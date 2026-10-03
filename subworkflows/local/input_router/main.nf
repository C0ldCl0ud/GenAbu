def readPdfSignature(input_path) {

    def input_stream = java.nio.file.Files.newInputStream(input_path)
    def signature_bytes = input_stream.readNBytes(5)

    input_stream.close()

    return new String(
        signature_bytes,
        java.nio.charset.StandardCharsets.US_ASCII
    )
}


/*
 * Route the single top-level --input file to the appropriate downstream
 * workflow. Detailed CSV and PDF validation remains the responsibility of
 * INPUT_VALIDATOR and PAPER_INPUT, respectively.
 */
workflow INPUT_ROUTER {

    take:
    input

    main:
    input_path = file(input)

    if (!java.nio.file.Files.exists(input_path)) {
        error "Input file does not exist: ${input}"
    }

    if (!java.nio.file.Files.isRegularFile(input_path)) {
        error "Input must be a regular file: ${input}"
    }

    input_name = input_path.getFileName().toString()
    extension = input_name.contains('.')
        ? input_name.substring(input_name.lastIndexOf('.') + 1).toLowerCase()
        : ''

    if (extension == 'csv') {
        samplesheet_ch = Channel.of(input_path)
        paper_ch = Channel.empty()
    }
    else if (extension == 'pdf') {
        if (java.nio.file.Files.size(input_path) < 5) {
            error "PDF input is empty or too short to be valid: ${input}"
        }

        signature = readPdfSignature(input_path)

        if (signature != '%PDF-') {
            error "File has a .pdf extension but no PDF signature: ${input}"
        }

        samplesheet_ch = Channel.empty()
        paper_ch = Channel.of(input_path)
    }
    else {
        error "Unsupported input type '${extension ?: 'none'}'. Expected a .csv or .pdf file: ${input}"
    }

    emit:
    samplesheet = samplesheet_ch
    paper = paper_ch
}
