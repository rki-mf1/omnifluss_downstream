process NEXTCLADE_PER_SAMPLE_TABLE {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pandas:1.4.3'
        : 'biocontainers/pandas:1.4.3'}"

    input:
    val(samplenames)
    path(nextclade_with_dataset_provenance)
    val(is_influenza)

    output:
    path("*_types_per_sample.tsv"), emit: per_sample_table
    path "versions.yml", emit: versions

    script:
    is_influenza_flag = is_influenza ? "--is-influenza" : ""
    """
    nextclade_per_sample_table.py \
        --samplenames ${samplenames.join(',')} \
        --nextclade_tsv ${nextclade_with_dataset_provenance.join(',')} \
        ${is_influenza_flag}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade_per_sample_table.py: \$(nextclade_per_sample_table.py --version | cut -d ' ' -f 2)
    END_VERSIONS
    """

    stub:
    """
    touch sample1_types_per_sample.tsv
    touch sample2_types_per_sample.tsv
    touch sample3_types_per_sample.tsv
    touch sample4_types_per_sample.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextclade_per_sample_table.py: \$(nextclade_per_sample_table.py --version | cut -d ' ' -f 2)
    END_VERSIONS
    """
}
