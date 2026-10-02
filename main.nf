include { validateParameters } from 'plugin/nf-schema'

workflow {

    validateParameters()

    log.info "Input validation successful"
}