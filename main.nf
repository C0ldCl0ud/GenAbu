include { INPUT_VALIDATOR } from './subworkflows/local/input_validator/main'


workflow {

    INPUT_VALIDATOR(params.input)

    ch_input   = INPUT_VALIDATOR.out.ch_input
    input_type = INPUT_VALIDATOR.out.input_type

}