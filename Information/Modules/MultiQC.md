---
type: module
input:
    - multiqc_files
    - multiqc_config
output:
    - report
    - data
    - plots (optional)
    - versions
image:
    - community.wave.seqera.io/library/multiqc:1.35--c17fb751507e9dfc
parent:
child:
tools:
    - MultiQC
---
# MultiQC

## Description
The MULTIQC module aggregates quality control reports and analysis metrics from multiple workflow steps into a centralized summary using MultiQC. It processes the staged input files according to the supplied MultiQC configuration file and generates an interactive HTML report, a directory containing the underlying report data, and optionally a directory containing plots.

All outputs are published to the results/multiqc directory. The module also records the MultiQC version in versions.yml. Its stub implementation creates placeholder report files and version metadata for testing without executing MultiQC.
