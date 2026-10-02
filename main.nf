include { INPUT_VALIDATOR } from './subworkflows/local/input_validator/main'
include { SRA_INPUT }       from './subworkflows/local/sra_input/main'
include { FALCO }           from './modules/local/falco/main'


workflow {

    INPUT_VALIDATOR(params.input)

    SRA_INPUT(INPUT_VALIDATOR.out.sra)

    ch_reads = INPUT_VALIDATOR.out.fastq
        .mix(SRA_INPUT.out.reads)

    FALCO(ch_reads)
}