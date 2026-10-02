process TEST_RUN {

    output:
    stdout

    script:
    """
    echo "Test run successfully"
    """
}

workflow {

    TEST_RUN().view()

}