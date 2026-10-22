---
type: module
input:
    - paper
output:
    - text
image:
    - quay.io/biocontainers/poppler:25.07.0
parent:
child:
tools:
    - pdftotext
    - grep
---
# PDF to Text

## Description
The PDF_TO_TEXT module extracts text from a PDF publication using pdftotext from the Poppler utilities. The extracted text is encoded in UTF-8, uses Unix-style line endings, and omits page-break characters. The output is saved as a text file named after the input PDF and published to results/paper_resolve.

After extraction, the module checks whether the output contains any non-whitespace characters. If no text is found, the process terminates with an error. This helps identify PDFs from which no usable text could be extracted. The stub implementation generates a placeholder text file for testing without processing the PDF.
