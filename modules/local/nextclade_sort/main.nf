process NEXTCLADE_SORT {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/93/936786744b34cf016b948026a6b4e9489011424e15c28dfb2f7d03c31bb4afb5/data' :
        'community.wave.seqera.io/library/nextclade:3.11.0--155203da8341cfe6' }"

    input:
    path(fastas)

    output:
    path "nextclade_sort/", emit: sort_directory
    path "versions.yml", emit: versions

    script:
    """
    nextclade sort $fastas --output-dir nextclade_sort/

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade: \$(echo \$(nextclade --version 2>&1) | sed 's/^.*nextclade //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    mkdir nextstrain

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade: \$(echo \$(nextclade --version 2>&1) | sed 's/^.*nextclade //; s/ .*\$//')
    END_VERSIONS
    """
}
