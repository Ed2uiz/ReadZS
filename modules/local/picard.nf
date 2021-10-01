process PICARD {
    tag "${bamName}"
    label 'process_medium'

    input:
    tuple val(inputChannel), val(bamFileID), path(bam)
    path picard

    output:
    tuple val(inputChannel), val(bamFileID), path("*dedup*"), emit: bam_tuple

    script:
    outputFile = "${bamFileID}.dedup"
    metrics = "${bamFileID}.metrics"
    """
    java -jar ${picard} MarkDuplicates -I ${bam} -O ${outputFile} -M ${metrics} --QUIET true
    """
}
