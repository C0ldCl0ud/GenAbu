include { PDF_TO_TEXT } from '../../../modules/local/pdf_to_text/main'
include { ACCESSION_EXTRACTOR } from '../../../modules/local/accession_extractor/main'


workflow PAPER_ACCESSIONS {

    take:
    paper

    main:
    PDF_TO_TEXT(paper)
    ACCESSION_EXTRACTOR(PDF_TO_TEXT.out.text)

    emit:
    text = PDF_TO_TEXT.out.text
    accessions = ACCESSION_EXTRACTOR.out.accessions
}
