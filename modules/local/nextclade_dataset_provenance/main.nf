process NEXTCLADE_DATASET_PROVENANCE {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pandas:1.4.3'
        : 'biocontainers/pandas:1.4.3'}"

    input:
    tuple val(meta), path(dataset_pathogen_json)
    tuple val(meta), path(nextclade_csv)

    output:
    tuple val(meta), path("${meta.id}_nextclade_dataset_provenance.tsv"), emit: dataset_provenance
    path "versions.yml", emit: versions

    script:
    """
    nextclade_dataset_provenance.py \
        --meta '${meta.id}' \
        --nextclade_csv ${nextclade_csv} \
        --json ${dataset_pathogen_json}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade_dataset_provenance.py: \$(nextclade_dataset_provenance.py --version | cut -d ' ' -f 2)
    END_VERSIONS
    """

    stub:
    """
    mkdir nextstrain

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade_dataset_provenance.py: \$(nextclade_dataset_provenance.py --version | cut -d ' ' -f 2)
    END_VERSIONS
    """
}
