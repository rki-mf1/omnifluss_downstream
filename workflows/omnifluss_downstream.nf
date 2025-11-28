/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { NEXTCLADE_SORT } from '../modules/local/nextclade_sort/main'
include { NEXTCLADE_DATASETGET } from '../modules/nf-core/nextclade/datasetget/main'
include { NEXTCLADE_RUN } from '../modules/nf-core/nextclade/run/main'
include { NEXTCLADE_POSTPROCESSING } from '../modules/local/nextclade_postprocessing/main'
include { NEXTCLADE_DATASET_PROVENANCE } from '../modules/local/nextclade_dataset_provenance/main'
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

    main:
    ch_consensus_sequences = ch_samplesheet
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // collect all consensus sequences
    ch_nextclade_sort_input = ch_consensus_sequences.collect { it[1] }


    //
    // NEXTCLADE_SORT:
    // Automatically deposit consensus sequences into species and clade subfolders 
    //
    NEXTCLADE_SORT(ch_nextclade_sort_input)
    ch_versions = ch_versions.mix(NEXTCLADE_SORT.out.versions)

    // channel: "path/to/nextstrain"
    ch_nextclade_sort = NEXTCLADE_SORT.out.sort_directory


    // combine directory from NEXTCLADE_SORT, file extensions, and tags according to selected pathogen
    // filter out files that don't exist (type/segment not present)
    // channel: [[id:tag], path/to/sequences.fasta]
    ch_nextclade_run_input = ch_nextclade_sort
        .combine(Channel.from(params.nextclade_sort_extensions.split(",")))
        .merge(Channel.from(params.nextclade_sort_tags.split(",")))
        .map { sort_directory, suffix, tag ->
            [[id: tag], file("${sort_directory}/${suffix}")]
        }
        .filter { _meta, path -> path.exists() }



    if (params.get_nextclade_dataset) {
        // channel: ["nextclade_reference_tag"]
        ch_nextclade_datasetget_input = Channel.from(params.nextclade_dataset_tags.split(","))

        //
        // NEXTCLADE_DATASETGET:
        // Download specified nextclade reference dataset
        //
        NEXTCLADE_DATASETGET(
            ch_nextclade_datasetget_input,
            "",
        )
        ch_versions = ch_versions.mix(NEXTCLADE_DATASETGET.out.versions)


        // channel: [[id:tag], path/to/nextclade_reference_set]
        ch_dataset = NEXTCLADE_DATASETGET.out.dataset.map { dataset ->
            def dir_name = dataset.getBaseName()
            [[id: params["mapping_" + dir_name]], dataset]
        }


        // join samples and datasets
        ch_tmp_join = ch_nextclade_run_input.join(ch_dataset)

        // channel: [[id:tag], path/to/sequences.fasta]
        ch_nextclade_run_input = ch_tmp_join.map { meta, sample, _dataset ->
            return [meta, sample]
        }
        ch_nextclade_run_input

        // channel: [path/to/nextclade_reference_set]
        ch_dataset = ch_tmp_join.map { _meta, _sample, dataset ->
            return dataset
        }
    }
    else {

        // use a mapping to load the references in the correct order
        // channel: [path/to/nextclade_reference_set]
        ch_dataset = ch_nextclade_run_input.map { meta, _path ->
            return params["dataset_" + meta.id]
        }
    }

    //
    // NEXTLCADE_RUN:
    // Perform the nextclade analysis on a set of consensus sequences, with their corresponding reference dataset
    //
    NEXTCLADE_RUN(
        ch_nextclade_run_input,
        ch_dataset,
    )
    ch_versions = ch_versions.mix(NEXTCLADE_RUN.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(NEXTCLADE_RUN.out.csv.map { meta, csv -> csv }.collect())

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
