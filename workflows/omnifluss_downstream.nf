/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { NEXTCLADE_SORT } from '../modules/local/nextclade_sort/main'
include { NEXTCLADE_DATASETGET } from '../modules/nf-core/nextclade/datasetget/main'
include { SORT_FASTA_BIOPYTHON } from '../modules/local/sort_fasta_biopython/main'
include { NEXTCLADE_RUN } from '../modules/nf-core/nextclade/run/main'
include { NEXTCLADE_POSTPROCESSING } from '../modules/local/nextclade_postprocessing/main'
include { NEXTCLADE_DATASET_PROVENANCE } from '../modules/local/nextclade_dataset_provenance/main'
include { NEXTCLADE_PER_SAMPLE_TABLE } from '../modules/local/nextclade_per_sample_table/main'
include { MULTIQC } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap } from 'plugin/nf-schema'
include { paramsSummaryMultiqc } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_omnifluss_downstream_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow OMNIFLUSS_DOWNSTREAM {
    take:
    ch_samplesheet // channel: samplesheet read in from --input
    ch_nextclade_dataset_config // channel: nextclade_dataset_config read in from --nextclade_dataset_config

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
    // existing paths are selected for further processing
    //
    ch_nextclade_sort_fasta_with_dataset = ch_nextclade_dataset_config
        .combine(NEXTCLADE_SORT.out.sort_directory)
        .map{ meta, dataset_path, nextclade_sort_path ->
            [meta, file("${nextclade_sort_path}/${dataset_path}")]
        }
        .filter { _meta, path -> path.exists() }

    //
    // SORT_FASTA_BIOPYTHON:
    // Sort fasta sequences by header ids to ensure consistent ordering
    //
    SORT_FASTA_BIOPYTHON(ch_nextclade_sort_fasta_with_dataset)
    ch_versions = ch_versions.mix(SORT_FASTA_BIOPYTHON.out.versions)

    ch_nextclade_input = SORT_FASTA_BIOPYTHON.out.sorted_fasta

    // Prepare input for nextclade datasetget
    ch_nextclade_datasetget_input = ch_nextclade_input.multiMap { meta, _fasta ->
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
    ch_versions = ch_versions.mix(NEXTCLADE_DATASETGET.out.versions)

    // Prepare input for nextclade run
    ch_nextclade_run_input = NEXTCLADE_DATASETGET.out.dataset
        .join(ch_nextclade_input)
        .multiMap{meta, dataset, fasta ->
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
    ch_versions = ch_versions.mix(NEXTCLADE_RUN.out.versions)

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
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'omnifluss_downstream_software_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true,
        )
        .set { ch_collated_versions }


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
