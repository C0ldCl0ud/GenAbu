---
type: process
input:
  - CSV samplesheet
  - PDF paper
output:
  - Validated samplesheet input
  - Validated paper input (file type and PDF signature)
image:
parent:
child:
tools:
---
# Input Router

## Description
The Input Router identifies the provided input file based on its file type and routes it to the appropriate downstream workflow. CSV files are routed to the samplesheet workflow, while PDF files are routed to the paper input workflow. Unsupported file types and invalid PDF files are rejected before downstream processing begins.