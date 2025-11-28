process NEXTCLADE_DATASET_PROVENANCE {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pandas:1.4.3'
        : 'biocontainers/pandas:1.4.3'}"

    input:
    tuple val(meta), path(dataset_pathogen_json), path(nextclade_csv)

    output:
    tuple val(meta), path("${prefix}_nextclade_dataset_provenance.tsv"), emit: mqc_dataset_provenance
    tuple val(meta), path("${prefix}_with_dataset_provenance.tsv"), emit: nextclade_with_dataset_provenance
    path "versions.yml", emit: versions

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    nextclade_dataset_provenance.py \
        --meta ${prefix} \
        --nextclade_csv ${nextclade_csv} \
        --json ${dataset_pathogen_json}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade_dataset_provenance.py: \$(nextclade_dataset_provenance.py --version | cut -d ' ' -f 2)
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch "${prefix}_nextclade_dataset_provenance.tsv"
    touch "${prefix}_with_dataset_provenance.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade_dataset_provenance.py: \$(nextclade_dataset_provenance.py --version | cut -d ' ' -f 2)
    END_VERSIONS
    """
}
