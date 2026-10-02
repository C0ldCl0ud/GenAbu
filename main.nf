include { INPUT_VALIDATOR } from './subworkflows/local/input_validator/main'
include { SRA_PREFETCH }   from './modules/local/sra_prefetch/main'


workflow {

    INPUT_VALIDATOR(params.input)

    SRA_PREFETCH(INPUT_VALIDATOR.out.sra)

}