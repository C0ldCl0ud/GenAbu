include { INPUT_ROUTER }          from './subworkflows/local/input_router/main'
include { INPUT_VALIDATOR }       from './subworkflows/local/input_validator/main'
include { PAPER_ACCESSIONS }      from './subworkflows/local/paper_accessions/main'
include { SRA_INPUT }             from './subworkflows/local/sra_input/main'
include { REFERENCE_PREPARATION } from './subworkflows/local/reference_preparation/main'
include { QUANTIFICATION }        from './subworkflows/local/quantification/main'

include { FALCO }                 from './modules/local/falco/main'
include { FALCO as FALCO_TRIM }    from './modules/local/falco/main'
include { CUTADAPT }              from './modules/local/cutadapt/main'
include { MULTIQC }               from './modules/local/multiqc/main'
include { GENE_ABUNDANCE }        from './modules/local/gene_abundance/main'


workflow {

    /*
     * Input resolution.
     */
    INPUT_ROUTER(params.input)

    INPUT_VALIDATOR(
        INPUT_ROUTER.out.samplesheet
    )

    PAPER_ACCESSIONS(
        INPUT_ROUTER.out.paper,
        params.max_runs
    )


    ch_versions = PAPER_ACCESSIONS.out.versions

    if (params.resolve_only) {

        log.info(
            'Resolve-only mode enabled: skipping SRA download and processing.'
        )
    }
    else {

        /*
         * Reference preparation.
         */
        if (params.genome) {

            ch_genome = Channel.value(
                params.genome
            )

            ch_reference_cache = Channel.value(
                params.reference_cache
            )

            REFERENCE_PREPARATION(
                ch_genome,
                ch_reference_cache
            )

            ch_versions = ch_versions.mix(REFERENCE_PREPARATION.out.versions)
        }


        /*
         * Resolve all SRA-based input.
         */
        ch_sra = INPUT_VALIDATOR.out.sra
            .mix(
                PAPER_ACCESSIONS.out.sra
            )

        SRA_INPUT(
            ch_sra
        )


        /*
         * Combine user-provided FASTQ files with FASTQ files
         * generated from SRA accessions.
         */
        ch_reads = INPUT_VALIDATOR.out.fastq
            .mix(
                SRA_INPUT.out.reads
            )


        /*
         * Raw-read quality control.
         */
        FALCO(
            ch_reads
        )


        /*
         * Adapter and quality trimming.
         */
        CUTADAPT(
            ch_reads,
            [
                r1: params.adapter_r1,
                r2: params.adapter_r2
            ],
            params.quality_cutoff,
            params.minimum_length
        )

        /*
         * Trimmed-read quality control
         */
        FALCO_TRIM(
            CUTADAPT.out.reads
        )

        /*
         * Transcript and gene abundance quantification.
         */
        if (params.genome) {

            QUANTIFICATION(
                CUTADAPT.out.reads,
                REFERENCE_PREPARATION.out.salmon_index,
                REFERENCE_PREPARATION.out.gtf
            )

                ch_gene_quant_files = QUANTIFICATION.out.gene_quant
                .map {
                    meta,
                    gene_quant ->

                    gene_quant
                }
                .collect()

            ch_salmon_multiqc = QUANTIFICATION.out.results
            .map {
                meta,
                salmon_dir ->

                salmon_dir
            }


            ch_abundance_gtf = REFERENCE_PREPARATION.out.gtf
                .map {
                    reference,
                    gtf_file ->

                    gtf_file
                }


            GENE_ABUNDANCE(
                ch_gene_quant_files,
                ch_abundance_gtf
            )

            ch_versions = ch_versions.mix(
                QUANTIFICATION.out.versions,
                GENE_ABUNDANCE.out.versions
            )

        }

        /*
         * Collect QC reports for MultiQC.
         */
        ch_falco_multiqc = FALCO.out.data
            .map {
                meta,
                files ->

                files
            }
            .flatten()


        ch_cutadapt_multiqc = CUTADAPT.out.report
            .map {
                meta,
                report ->

                report
            }

        ch_falco_trim_multiqc = FALCO_TRIM.out.data
            .map {
                meta,
                files ->

                files
            }
            .flatten()


        ch_multiqc_files = ch_falco_multiqc
            .concat(
                ch_cutadapt_multiqc,
                ch_falco_trim_multiqc,
            )

        if (params.genome) {
            ch_multiqc_files = ch_multiqc_files
                .concat(
                    ch_salmon_multiqc
                )
        }

        ch_multiqc_config = Channel.value(
            file("${projectDir}/assets/multiqc_config.yml")
        )

        MULTIQC(
            ch_multiqc_files.collect(),
            ch_multiqc_config
        )

        ch_versions = ch_versions.mix(CUTADAPT.out.versions, MULTIQC.out.versions)
    }

    ch_versions
        .map { it.text.trim() }
        .mix(Channel.value("\"Workflow\":\n    nextflow: \"${workflow.nextflow.version}\""))
        .unique()
        .collectFile(
            name: 'software_versions.yml',
            storeDir: "${launchDir}/results/pipeline_info",
            sort: true,
            newLine: true
        )
}
