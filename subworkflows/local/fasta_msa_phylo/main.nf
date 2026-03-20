include { MAFFT_ALIGN } from '../../../modules/nf-core/mafft/align/main'
include { IQTREE } from '../../../modules/nf-core/iqtree/main'
include { TREETIME_ANCESTRAL } from '../../../modules/local/treetime/ancestral/main'


workflow FASTA_MSA_PHYLO {
    take:
    ch_fasta // channel: [ val(meta), [ fasta ] ]

    main:
    ch_mafft_input = ch_fasta.map { meta, fas -> 
        // Find header containing "root"
        def rootHeader = fas.text
            .split('\n')
            .findAll { it -> it.startsWith('>') }
            .find { it -> it.toLowerCase().contains('root') }
        
        // Safe extraction with null check
        def outgroupId = rootHeader 
            ? rootHeader.replaceAll('^>', '').split(/\s+/)[0]
            : false
        
        // Add to outgroup_id meta for IQ-TREE
        [meta + [outgroup_id: outgroupId], fas]
    }

    MAFFT_ALIGN(
        ch_mafft_input,
        [[], []],
        [[], []],
        [[], []],
        [[], []],
        [[], []],
        false,
    )

    ch_iqtree_input = MAFFT_ALIGN.out.fas.map { meta, fas ->
        [meta, fas, []]
    }
    IQTREE(
        ch_iqtree_input,
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
    )
    ch_treetime_json = channel.empty()
    TREETIME_ANCESTRAL(
        IQTREE.out.phylogeny.join(MAFFT_ALIGN.out.fas)
    )
    ch_treetime_json = TREETIME_ANCESTRAL.out.json

    emit:
    msa = MAFFT_ALIGN.out.fas // channel: [ val(meta), [ fas ] ]
    tree = TREETIME_ANCESTRAL.out.tree // channel: [ val(meta), [ nexus ] ]
    json = ch_treetime_json // channel: [ val(meta), [ json ] ]
}
