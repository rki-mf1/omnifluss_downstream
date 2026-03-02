/*
 * Process to concatenate FASTA records by their headers
 * Input: [meta, [fasta1, fasta2, ...]]
 * Output: [meta, concatenated_fasta]
 */
process FASTA_CONCAT_BY_HEADER_AND_FILTER {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pandas:1.4.3'
        : 'biocontainers/pandas:1.4.3'}"

    input:
    tuple val(meta), path(fastas)
    val(exclude_patters)
    val(x_threshold)

    output:
    tuple val(meta), path("${meta.id}_concatenated.fasta")

    script:
    """
    #!/usr/bin/env python3
    
    from collections import defaultdict
    import sys
    
    # Dictionary to store sequences by header
    sequences_by_header = defaultdict(list)
    
    # Process all input fasta files
    fasta_files = "${fastas}".split()

    exclude_patterns = "${exclude_patters}".split()
    
    for fasta_file in fasta_files:
        current_header = None
        current_seq = []
        
        with open(fasta_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('>'):
                    # Save previous sequence if exists
                    if current_header:
                        sequences_by_header[current_header].append(''.join(current_seq))
                    
                    # Start new sequence
                    current_header = line
                    current_seq = []
                else:
                    current_seq.append(line)
            
            # Save last sequence
            if current_header:
                sequences_by_header[current_header].append(''.join(current_seq))
    
    # Write concatenated sequences to output
    with open('${meta.id}_concatenated.fasta', 'w') as out:
        for header in sorted(sequences_by_header.keys()):
            # Check for exclude patterns
            if any(pattern in header for pattern in exclude_patterns):
                continue

            # Concatenate all sequences for this header
            concatenated_seq = ''.join(sequences_by_header[header])

            # Filter based on X content
            x_count = concatenated_seq.count('X')
            if len(concatenated_seq) == 0:
                continue
            if (x_count / len(concatenated_seq)) >= float("${x_threshold}"):
                continue

            out.write(header + '\\n')
            # Write in 80 character lines
            for i in range(0, len(concatenated_seq), 80):
                out.write(concatenated_seq[i:i+80] + '\\n')
    """
}
