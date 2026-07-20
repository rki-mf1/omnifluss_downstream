include { MAFFT_ALIGN } from '../../../modules/nf-core/mafft/align/main'
include { IQTREE } from '../../../modules/nf-core/iqtree/main'
include { TREETIME_ANCESTRAL } from '../../../modules/local/treetime/ancestral/main'


workflow FASTA_MSA_PHYLO {
    take:
    ch_fasta // channel: [ val(meta), [ fasta ] ]

    main:
    ch_versions = channel.empty()

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
    ch_versions = ch_versions.mix(MAFFT_ALIGN.out.versions.first())
    
    ch_iqtree_input = MAFFT_ALIGN.out.fas
        .branch { meta, fas ->
            def seqCount = fas.text.readLines().count { line -> line.startsWith('>') }
            
            skip_tree_build: seqCount <= 2
                log.warn "Sample ${meta.id}: Only ${seqCount} sequence(s) - skipping IQTREE (minimum 3 required)"
                return [meta, fas, []]

            pass_no_bootstrap: seqCount == 3
                meta = meta + [bootstrap: '']
                log.warn "Sample ${meta.id}: Only ${seqCount} sequences - bootstrapping for IQTREE disabled (minimum 4 required)"
                return [meta, fas, []]

            pass_bootstrap: seqCount >= 4
                meta = meta + [bootstrap: '-bb 1000']
                return [meta, fas, []]
        }
    
    IQTREE(
        ch_iqtree_input.pass_no_bootstrap.mix(ch_iqtree_input.pass_bootstrap),
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
    ch_versions = ch_versions.mix(IQTREE.out.versions.first())

    // remove bootstrap meta for propper joining on the meta map
    ch_iqtree_pylo_output = IQTREE.out.phylogeny.map { meta, treefile ->
        [meta.findAll { k, v -> k != 'bootstrap' }, treefile]
    }

    TREETIME_ANCESTRAL(
        ch_iqtree_pylo_output.join(MAFFT_ALIGN.out.fas)
    )
    ch_versions = ch_versions.mix(TREETIME_ANCESTRAL.out.versions)

    emit:
    msa = MAFFT_ALIGN.out.fas // channel: [ val(meta), [ fas ] ]
    tree = TREETIME_ANCESTRAL.out.tree // channel: [ val(meta), [ nexus ] ]
    json = TREETIME_ANCESTRAL.out.json // channel: [ val(meta), [ json ] ]
    versions = ch_versions // channel: [ path(versions.yml) ]
}
