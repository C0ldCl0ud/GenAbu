process PDF_TO_TEXT {

    tag "${paper.simpleName}"
    label 'process_low'

    container 'quay.io/biocontainers/poppler:25.07.0'

    input:
    path paper

    output:
    path "${paper.simpleName}.txt", emit: text

    script:
    def output_name = "${paper.simpleName}.txt"

    """
    pdftotext \
        -enc UTF-8 \
        -eol unix \
        -nopgbrk \
        "${paper}" \
        "${output_name}"

    if ! grep -q '[^[:space:]]' "${output_name}"; then
        echo "PDF_TO_TEXT could not extract text from ${paper}" >&2
        exit 1
    fi
    """

    stub:
    """
    printf 'GenAbu PDF text extraction stub\n' > "${paper.simpleName}.txt"
    """
}
