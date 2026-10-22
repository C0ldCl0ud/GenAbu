---
type: module
input:
    - reference, reference_cache
output:
    - reference_files
    - versions
image:
    - community.wave.seqera.io/library/wget:1.21.4--8b0fcde81c17be5e
parent:
    - REFERENCE_RESOLVER
child:
tools:
    - wget
    - gzip
    - cat
---
# REFERENCE_DOWNLOAD

## Description
The REFERENCE_DOWNLOAD module downloads genome sequence and gene annotation files for a selected reference genome using wget. The download URLs and reference metadata are provided through the reference input. Retry and timeout options are configured to improve download robustness.

After downloading, the module validates both compressed files using gzip -t and generates a reference.yml manifest containing the reference identifier, species, assembly information, source, release, and download URLs. The genome FASTA, GTF annotation, and manifest are emitted together with the reference metadata. The files are published to a persistent cache directory organized by source, release, reference identifier, and assembly. The module also records the wget version in versions.yml.

The stub implementation creates small placeholder genome and annotation files, along with a corresponding manifest and version information, for testing without downloading reference data.
