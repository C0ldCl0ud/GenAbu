process MULTIQC {

    tag "MultiQC"
    label 'process_low'

    container 'community.wave.seqera.io/library/multiqc:1.35--c17fb751507e9dfc'

    publishDir 'results/multiqc',
        mode: 'copy',
        overwrite: true

    input:
    path multiqc_files, stageAs: "?/*"
    path multiqc_config

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_data",        emit: data
    path "multiqc_plots",       emit: plots, optional: true
    path "versions.yml",        emit: versions

    script:
    """
    multiqc \
        --force \
        --config "${multiqc_config}" \
        .

    printf '"%s":\\n    multiqc: "%s"\\n' \
        "${task.process}" \
        "\$(multiqc --version | awk '{print \$NF}')" \
        > versions.yml
    """

    stub:
    """
    touch multiqc_report.html

    mkdir -p multiqc_data
    touch multiqc_data/.stub

    printf '"%s":\\n    multiqc: "1.35"\\n' \
        "${task.process}" \
        > versions.yml
    """
}