/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { NEXTCLADE_SORT         } from '../modules/local/nextclade_sort/main'
include { NEXTCLADE_DATASETGET   } from '../modules/nf-core/nextclade/datasetget/main'
include { NEXTCLADE_RUN          } from '../modules/nf-core/nextclade/run/main' 
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
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

    // collect all channels
    ch_nextclade_sort_input = ch_consensus_sequences.collect{it[1]}

    NEXTCLADE_SORT(ch_nextclade_sort_input)

    //combine sort_directory, file endings and tags according to selected pathogen
    //filter out files that don't exist (type/segment not present)
    ch_nextclade_run_input = NEXTCLADE_SORT.out.sort_directory
                                .combine( Channel.from(params.nextclade_sort_extensions.split(",")))
                                .merge( Channel.from(params.nextclade_sort_tags.split(",")))
                                .map {sort_directory, suffix, tag ->
                                    [[id: tag], file("${sort_directory}/${suffix}")]
                                }
                                .filter {_meta, path -> path.exists()}

    if (params.get_nextclade_dataset) { 
        ch_nextclade_datasetget_input = Channel.from(params.nextclade_dataset_tags.split(","))

        NEXTCLADE_DATASETGET(
            ch_nextclade_datasetget_input,
            ""
        )

        ch_dataset = NEXTCLADE_DATASETGET.out.dataset.map{ dataset ->
            def dir_name = dataset.getBaseName()
            [[id:params["mapping_"+ dir_name]], dataset]
        }
        
        // join samples and datasets
        ch_tmp_join = ch_nextclade_run_input.join(ch_dataset)

        ch_nextclade_run_input = ch_tmp_join.map { meta, sample, _dataset ->
            return [meta, sample] 
        }

        ch_dataset = ch_tmp_join.map { _meta, _sample, dataset ->
            return dataset
        }

    } else {

        // use a mapping to load the references in the correct order
        ch_dataset = ch_nextclade_run_input.map { meta, _path ->
            return params["dataset_"+ meta.id]
        }

    }

    NEXTCLADE_RUN(
        ch_nextclade_run_input,
        ch_dataset
    )

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'omnifluss_downstream_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
