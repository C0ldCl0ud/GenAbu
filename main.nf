include { INPUT_ROUTER }    from './subworkflows/local/input_router/main'
include { INPUT_VALIDATOR } from './subworkflows/local/input_validator/main'
include { PAPER_ACCESSIONS } from './subworkflows/local/paper_accessions/main'
include { SRA_INPUT }       from './subworkflows/local/sra_input/main'
include { FALCO }           from './modules/local/falco/main'


workflow {

    INPUT_ROUTER(params.input)

    INPUT_VALIDATOR(INPUT_ROUTER.out.samplesheet)
    PAPER_ACCESSIONS(INPUT_ROUTER.out.paper)

    ch_sra = INPUT_VALIDATOR.out.sra
        .mix(PAPER_ACCESSIONS.out.sra)

    SRA_INPUT(ch_sra)

    ch_reads = INPUT_VALIDATOR.out.fastq
        .mix(SRA_INPUT.out.reads)

    FALCO(ch_reads)
}
