---
type: module
input:
    - paper_text
output:
    - accessions
image:
    - python:3.12-slim
parent:
child:
tools:
    - Python 3.12
    - extract_accessions.py
---
# Accession Extractor

## Description
The Accession Extractor identifies sequencing data accession identifiers in the provided scientific publication text. It executes the extract_accessions.py Python script, which extracts the detected accessions together with their associated repository, accession type, and source file information. The results are written to a tab-separated values (TSV) file containing one row per extracted accession. If no accessions are found, the output file still contains the header. A stub implementation generates a header-only TSV file for testing purposes.