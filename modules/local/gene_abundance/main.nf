process GENE_ABUNDANCE {

    tag 'Gene abundance matrix'
    label 'process_low'

    container 'python:3.13.7-bookworm'

    publishDir 'results',
        mode: 'copy',
        overwrite: true,
        pattern: 'gene_*.tsv'

    input:
    path gene_quant_files
    path gtf

    output:
    path "gene_counts.tsv",
         emit: counts

    path "gene_abundance.tsv",
         emit: abundance

    path "versions.yml",
         emit: versions

    script:
    def quant_args = (gene_quant_files instanceof List ? gene_quant_files : [gene_quant_files])
        .collect { "'${it.toString().replace("'", "'\\''")}'" }
        .join(' ')
    def gtf_arg = "'${gtf.toString().replace("'", "'\\''")}'"
    """
    python3 "\$(command -v gene_abundance.py)" --gtf ${gtf_arg} --quant ${quant_args}

    test -s gene_counts.tsv
    test -s gene_abundance.tsv

    printf '"%s":\\n    python: "%s"\\n' \
        "${task.process}" \
        "\$(python3 --version | awk '{print \$2}')" \
        > versions.yml
    """

    stub:
    """
    cat > gene_counts.tsv <<'EOF'
gene_id	sample1
GENESTUB000001	10.0
EOF

    cat > gene_abundance.tsv <<'EOF'
gene_id	sample1
GENESTUB000001	1000000.0
EOF

    printf '"%s":\\n    python: "3.13.7"\\n' \
        "${task.process}" \
        > versions.yml
    """
}