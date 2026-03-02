process TREETIME_ANCESTRAL {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/treetime:0.11.3--pyhdfd78af_0':
        'biocontainers/treetime:0.11.3--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(tree), path(alignment)

    output:
    tuple val(meta), path("${prefix}_ancestral_tree.nexus")     , emit: tree
    tuple val(meta), path("${prefix}_ancestral.fasta")          , emit: fasta
    tuple val(meta), path("${prefix}_branch_mutations.txt")     , emit: mutations, optional: true
    tuple val(meta), path("${prefix}_auspice_tree.json"), emit: json, optional: true
    tuple val(meta), path("${prefix}_sequence_evolution_model.txt"), emit: model, optional: true
    path "versions.yml"                                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    treetime ancestral \\
        --tree ${tree} \\
        --aln ${alignment} \\
        --outdir results \\
        ${args}

    # Rename output files
    mv results/annotated_tree.nexus ${prefix}_ancestral_tree.nexus
    mv results/ancestral_sequences.fasta ${prefix}_ancestral.fasta
    
    # Optional outputs
    [ -f results/branch_mutations.txt ] && mv results/branch_mutations.txt ${prefix}_branch_mutations.txt || true
    [ -f results/auspice_tree.json ] && mv results/auspice_tree.json ${prefix}_auspice_tree.json || true
    [ -f results/sequence_evolution_model.txt ] && mv results/sequence_evolution_model.txt ${prefix}_sequence_evolution_model.txt || true

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        treetime: \$(treetime --version 2>&1 | sed 's/treetime //g')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_ancestral_tree.nwk
    touch ${prefix}_ancestral.fasta
    touch ${prefix}_mutations.txt
    touch ${prefix}_ancestral_sequences.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        treetime: \$(treetime --version 2>&1 | sed 's/treetime //g')
    END_VERSIONS
    """
}