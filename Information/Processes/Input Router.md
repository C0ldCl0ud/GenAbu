---
type: process
input:
  - input
output:
  - samplesheet
  - paper
image:
parent:
child:
tools:
  - Nextflow
  - Groovy
---
# Input Router

## Description
The Input Router identifies the provided input file based on its file type and routes it to the appropriate downstream workflow. CSV files are routed to the samplesheet workflow, while PDF files are routed to the paper input workflow. Unsupported file types and invalid PDF files are rejected before downstream processing begins.