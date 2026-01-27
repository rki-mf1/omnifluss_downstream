process SORT_FASTA_BIOPYTHON {
    tag "${meta.id}"
    label 'process_low'
    
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/biopython:1.84' :
        'quay.io/biocontainers/biopython:1.84' }"
    
    input:
    tuple val(meta), path(fasta)
    
    output:
    tuple val(meta), path("${prefix}.sorted.fasta"), emit: sorted_fasta
    path "versions.yml"                             , emit: versions
    
    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    #!/usr/bin/env python3
    
    from Bio import SeqIO
    import sys
    
    # Read all sequences from the multi-FASTA file
    records = list(SeqIO.parse("${fasta}", "fasta"))
    
    # Sort by sequence ID (header)
    records.sort(key=lambda x: x.id)
    
    # Write sorted sequences
    with open("${prefix}.sorted.fasta", "w") as out_handle:
        SeqIO.write(records, out_handle, "fasta")
    
    print(f"Sorted {len(records)} sequences by header name", file=sys.stderr)
    
    # Write versions
    import Bio
    with open("versions.yml", "w") as f:
        f.write('"${task.process}":\\n')
        f.write(f'    biopython: "{Bio.__version__}"\\n')
    """
}