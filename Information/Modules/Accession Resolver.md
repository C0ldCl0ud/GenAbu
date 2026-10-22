---
type: module
input:
    - accessions
    - max_runs
output:
    - resolved
    - unresolved
    - samplesheet
    - versions
image:
    - community.wave.seqera.io/library/pip_ffq:fdd5a80e518d34b0
parent:
child:
tools:
    - ffq
    - Python
    - resolve_accession.py
---
# Accession Resolver

## Description
The Accession Resolver processes sequencing data accession identifiers extracted from scientific publications. It uses the resolve_accessions.py Python script together with ffq to retrieve and resolve accession metadata, including study, sample, experiment, and run identifiers. The max_runs parameter limits the number of runs considered during resolution.

The process separates successfully resolved accessions from unresolved entries, recording reasons for unresolved accessions where available. It also generates a samplesheet.csv containing the resolved sequencing run identifiers for downstream processing. If no accessions can be resolved, the process fails rather than producing an empty samplesheet. Software version information for ffq and the accession resolver is recorded in versions.yml to support reproducibility.

A stub implementation provides representative resolved and unresolved TSV files, a sample samplesheet, and version information for testing purposes.