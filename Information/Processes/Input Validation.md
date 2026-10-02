---
type: process
input: path
output:
image:
parent:
child:
tools:
---
# Input Validation

# Description

The Input Validation process validates the provided samplesheet with `nf-schema` before any downstream processing begins. It verifies the required samplesheet structure, checks sample identifiers for invalid values, and ensures that referenced input files are valid. Invalid input causes the pipeline to fail early with a clear validation error.