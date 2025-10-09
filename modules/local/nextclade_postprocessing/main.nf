process NEXTCLADE_POSTPROCESSING {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas%3A2.2.1' :
        'community.wave.seqera.io/library/pandas:2.2.1' }"

    input:
    tuple val(meta), path(csv)

    output:
    path "${meta.id}_nextclade_adapted.csv", emit: adapted_csv
    path "versions.yml", emit: versions

    script:
    """
    nextclade_postprocessing.py $meta.id $csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade_postprocessing.py: \$(nextclade_postprocessing.py --version | cut -d ' ' -f 2)
    END_VERSIONS
    """

    stub:
    """
    touch "${meta.id}_nextclade_adapted.csv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade_postprocessing.py: \$(nextclade_postprocessing.py --version | cut -d ' ' -f 2)
    END_VERSIONS
    """
}
