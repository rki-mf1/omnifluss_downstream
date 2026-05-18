/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { CAT_CAT } from '../modules/nf-core/cat/cat/main'
include { NEXTCLADE_SORT } from '../modules/local/nextclade_sort/main'
include { SEQKIT_SORT } from '../modules/nf-core/seqkit/sort/main'
include { NEXTCLADE_DATASETGET } from '../modules/nf-core/nextclade/datasetget/main'
include { NEXTCLADE_RUN } from '../modules/nf-core/nextclade/run/main'
include { NEXTCLADE_POSTPROCESSING } from '../modules/local/nextclade_postprocessing/main'
include { NEXTCLADE_DATASET_PROVENANCE } from '../modules/local/nextclade_dataset_provenance/main'
include { NEXTCLADE_PER_SAMPLE_TABLE } from '../modules/local/nextclade_per_sample_table/main'
include { FASTA_MSA_PHYLO } from '../subworkflows/local/fasta_msa_phylo/main'
include { MULTIQC } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap } from 'plugin/nf-schema'
include { paramsSummaryMultiqc } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_omnifluss_downstream_pipeline'
include { FASTA_CONCAT_BY_HEADER_AND_FILTER } from '../modules/local/fasta_concat_by_header_and_filter/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow OMNIFLUSS_DOWNSTREAM {
    take:
    ch_samplesheet // channel: samplesheet read in from --input
    ch_nextclade_dataset_config // channel: nextclade_dataset_config read in from --nextclade_dataset_config
    ch_phylo_external_sequences // channel: phylo_external_sequences read in from --phylo_external_sequences

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // NEXTCLADE_SORT:
    // Automatically deposit consensus sequences into species and clade subfolders 
    //
    ch_nextclade_sort_input = ch_samplesheet.collect { it[1] }
    NEXTCLADE_SORT(ch_nextclade_sort_input)
    ch_versions = ch_versions.mix(NEXTCLADE_SORT.out.versions)


    //
    // Prepare input:
    // select all fasta files from nextclade sort output that correspond to the datasets specified in the nextclade dataset config
    // the work dir path to the nextclade sort output is combined with the dataset paths from the nextclade dataset config
    // existing paths are selected for further processing (path/to/nextclade/sort/output)
    //
    ch_nextclade_datasets_unsorted = ch_nextclade_dataset_config
        .combine(NEXTCLADE_SORT.out.sort_directory)
        .map { meta, dataset_path, nextclade_sort_path ->
            [meta, file("${nextclade_sort_path}/${dataset_path}")]
        }
        .filter { _meta, path -> path.exists() }

    // Sort fasta by header ID
    SEQKIT_SORT(ch_nextclade_datasets_unsorted)
    ch_nextclade_datasets = SEQKIT_SORT.out.fastx

    ch_nextclade_datasetget_input = ch_nextclade_datasets.multiMap { meta, _fasta ->
        dataset_name: [meta, meta.dataset_name]
        dataset_tag: params.latest_nextclade_dataset ? "" : meta.dataset_tag
    }

    //
    // NEXTCLADE_DATASETGET:
    // Download specified nextclade reference dataset
    //
    NEXTCLADE_DATASETGET(
        ch_nextclade_datasetget_input.dataset_name,
        ch_nextclade_datasetget_input.dataset_tag,
    )

    // Prepare input for nextclade run
    ch_nextclade_run_input = NEXTCLADE_DATASETGET.out.dataset
        .join(ch_nextclade_datasets)
        .multiMap { meta, dataset, fasta ->
            samples: [meta, fasta]
            dataset: [dataset]
        }

    //
    // NEXTLCADE_RUN:
    // Perform the nextclade analysis on a set of consensus sequences, with their corresponding reference dataset
    //
    NEXTCLADE_RUN(
        ch_nextclade_run_input.samples,
        ch_nextclade_run_input.dataset,
    )

    //
    // NEXTCLADE_DATASET_PROVENANCE
    // Extract dataset version information from nextclade dataset json and nextclade csv output
    // Combined information from the nextclade dataset json that was run on the respective sequences
    //
    NEXTCLADE_DATASET_PROVENANCE(
        NEXTCLADE_RUN.out.dataset_pathogen_json.join(NEXTCLADE_RUN.out.csv)
    )
    ch_versions = ch_versions.mix(NEXTCLADE_DATASET_PROVENANCE.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(NEXTCLADE_DATASET_PROVENANCE.out.mqc_dataset_provenance.map { _meta, provenance -> provenance }.collect())

    //
    // NEXTCLADE_POSTPROCESSING
    // Perform one-hot-encoding on the columns: "aaSubstitutions", "aaDeletions" and "aaInsertions" of the resulting nextclade csv 
    //
    NEXTCLADE_POSTPROCESSING(
        NEXTCLADE_RUN.out.csv
    )
    ch_versions = ch_versions.mix(NEXTCLADE_POSTPROCESSING.out.versions)

    //
    // If segmented, collect Nextclade results with dataset provenance per-sample
    //
    if (params.genomes_is_segmented) {
        NEXTCLADE_PER_SAMPLE_TABLE(
            ch_samplesheet.map { meta, _path -> meta.id }.collect(),
            NEXTCLADE_DATASET_PROVENANCE.out.nextclade_with_dataset_provenance.map { _meta, path -> path }.collect(),
            workflow.profile.contains('INV'),
        )
        ch_versions = ch_versions.mix(NEXTCLADE_PER_SAMPLE_TABLE.out.versions)
        ch_multiqc_files = ch_multiqc_files.mix(NEXTCLADE_PER_SAMPLE_TABLE.out.per_sample_table.collect())
    }

    //
    // prepare translated fastas for phylogenetic analysis
    //
    if (workflow.profile.contains('INV')) {
        ch_selcted_prot_fasta = NEXTCLADE_RUN.out.fasta_translation
            .filter { meta, _fastas ->
                meta.id.endsWith('_HA')
            }
            .map { meta, fastas ->
                def fasta_filtered = fastas.findAll { fasta ->
                    fasta.name.contains('.HA1.') || fasta.name.contains('.HA2.')
                }
                [meta, fasta_filtered]
            }
            .filter { _meta, fastas -> fastas.size() == 2 }
            .map { meta, fastas ->
                def fasta_ha1 = fastas.find { fasta -> fasta.name.contains('.HA1.') }
                def fasta_ha2 = fastas.find { fasta -> fasta.name.contains('.HA2.') }
                [meta, [fasta_ha1, fasta_ha2]]
            }
    }
    else if (workflow.profile.contains('CVD')) {
        ch_selcted_prot_fasta = NEXTCLADE_RUN.out.fasta_translation.map { meta, fastas ->
            def fasta_filtered = fastas.findAll { fasta ->
                fasta.name.contains('.S.')
            }
            [meta, fasta_filtered]
        }
    }
    else {
        // all available transladed fasta records  from Nextclade run ouput
        ch_selcted_prot_fasta = NEXTCLADE_RUN.out.fasta_translation.collect()
    }

    //
    // concat amino-acid fasta records samples-wise into single fasta
    //
    FASTA_CONCAT_BY_HEADER_AND_FILTER(
        ch_selcted_prot_fasta,
        params.phylo_exclude_patterns ? params.phylo_exclude_patterns : [],
        params.phylo_min_X_fraction ? params.phylo_min_X_fraction : [],
    )
    ch_prot_fasta = FASTA_CONCAT_BY_HEADER_AND_FILTER.out.fasta

    //
    // add external sequences for phylogenetic analysis
    // concat with external input aa fasta file with full length HA sequences for reference
    // if ch_phylo_external_sequences is not empty, concat with ch_prot_fasta
    // else, just use ch_prot_fasta
    //
    ch_cat_input = params.phylo_external_sequences
        ? ch_phylo_external_sequences.map { meta, fas ->
            [meta.id, fas]
        }.join(
            ch_prot_fasta.map { meta, fas ->
                [meta.id, meta, fas]
            }
        ).map { _id, ext_fas, meta, fas ->
            [meta, [ext_fas, fas]]
        }
        : ch_prot_fasta
    CAT_CAT(ch_cat_input)
    ch_versions = ch_versions.mix(CAT_CAT.out.versions)

    //
    // Multiple sequence aligment and phylogenetic analysis
    //
    FASTA_MSA_PHYLO(
        CAT_CAT.out.file_out
    )
    ch_versions = ch_versions.mix(FASTA_MSA_PHYLO.out.versions)

    //
    // Collate and save software versions
    //

        //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'omnifluss_downstream_software_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true
        )
        
    //
    // MODULE: MultiQC
    //
    ch_multiqc_config = Channel.fromPath(
        "${projectDir}/assets/multiqc_config.yml",
        checkIfExists: true
    )
    ch_multiqc_custom_config = params.multiqc_config
        ? Channel.fromPath(params.multiqc_config, checkIfExists: true)
        : Channel.empty()
    ch_multiqc_logo = params.multiqc_logo
        ? Channel.fromPath(params.multiqc_logo, checkIfExists: true)
        : Channel.empty()

    summary_params = paramsSummaryMap(
        workflow,
        parameters_schema: "nextflow_schema.json"
    )
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml')
    )
    ch_multiqc_custom_methods_description = params.multiqc_methods_description
        ? file(params.multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description)
    )

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true,
        )
    )

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        [],
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions = ch_versions // channel: [ path(versions.yml) ]
}
