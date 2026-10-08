---
type: process
input:
  - PDF paper
  - Maximum number of SRA runs
output:
  - Extracted paper text
  - Extracted accessions
  - Resolved accessions
  - Unresolved accessions
  - SRA samplesheet
  - SRA run information
image:
parent:
child:
  - PDF_TO_TEXT
  - ACCESSION_EXTRACTOR
  - ACCESSION_RESOLVER
tools:
  - Nextflow
---
# PAPER ACCESSION

## Description
The Paper Accessions workflow extracts SRA accession numbers from a provided paper and resolves them to available SRA run information. It converts the PDF to text, identifies accession numbers, and retrieves the corresponding sample and run metadata. Resolved accessions are converted into an SRA samplesheet for downstream processing, while unresolved accessions are reported separately.