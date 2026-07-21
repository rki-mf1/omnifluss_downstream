process FASTA_CONCAT_BY_HEADER_AND_FILTER {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/python:3.11'
        : 'biocontainers/python:3.11'}"

    input:
    tuple val(meta), path(fastas)
    val exclude_patterns
    val x_threshold

    output:
    tuple val(meta), path("*.fasta"), emit: fasta
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def exclude_list = exclude_patterns ? "--exclude_patterns \"${exclude_patterns}\"" : ''
    def x_threshold_param = x_threshold ? "--x_threshold ${x_threshold}" : ''
    """
    fasta_concat_filter.py \\
        --fastas ${fastas} \\
        --output ${prefix}_concatenated.fasta \\
        ${exclude_list} \\
        ${x_threshold_param} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_concatenated.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
