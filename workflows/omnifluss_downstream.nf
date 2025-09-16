/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { SEQKIT_GREP            } from '../modules/nf-core/seqkit/grep/main'
include { CAT_CAT                } from '../modules/nf-core/cat/cat/main'
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

    // read in pattern files into a channel
    ch_pattern = Channel.fromPath("${projectDir}/assets/pattern/*").map { file ->
        def file_name = file.getBaseName()
        [[pattern_id: file_name], file]
    }

    // prepare input for seqkit grep
    // perform a cross-product between sample and pattern, such that all patterns are applied to all samples
    seqkit_grep_input = ch_consensus_sequences.combine(ch_pattern)
        .multiMap { meta, fasta, pattern_meta, pattern ->
            def newMeta = meta + pattern_meta
            fasta: [newMeta, fasta]
            pattern: pattern
    }

    // extract files matching the defined pattern
    SEQKIT_GREP(
        seqkit_grep_input.fasta,
        seqkit_grep_input.pattern
    )
    ch_sequences = SEQKIT_GREP.out.filter

    // sort samples into separate channels based on types and segments
    ch_sequences = ch_sequences.branch { meta, fasta ->
        h1n1_ha: meta.pattern_id == "H1N1_HA" 
            return fasta
        h3n2_ha: meta.pattern_id == "H3N2_HA" 
            return fasta
        h0n0_ha: meta.pattern_id == "H0N0_HA" 
            return fasta
        h1n1_na: meta.pattern_id == "H1N1_NA"  
            return fasta
        h3n2_na: meta.pattern_id == "H3N2_NA" 
            return fasta
        h0n0_na: meta.pattern_id == "H0N0_NA" 
            return fasta
    }

    if (params.get_nextclade_dataset) {
        ch_dataset_names = Channel.of("flu_h1n1pdm_ha","flu_h1n1pdm_na", "flu_h3n2_ha", "flu_h3n2_na", "flu_vic_ha", "flu_vic_na")

        NEXTCLADE_DATASETGET(
            ch_dataset_names,
            ""
        )

        ch_datasets = NEXTCLADE_DATASETGET.out.dataset.branch{ file -> 
            def file_name = file.getBaseName()
            h1n1_ha: file_name == "flu_h1n1pdm_ha"
                return [[id: params.runid+"_h1n1_ha", type: "h1n1", segment: "ha"], file]
            h3n2_ha: file_name == "flu_h3n2_ha"
                return [[id: params.runid+"_h3n2_ha", type: "h3n2", segment: "ha"], file]
            h0n0_ha: file_name == "flu_vic_ha"
                return [[id: params.runid+"_h0n0_ha", type: "h0n0", segment: "ha"], file]
            h1n1_na: file_name == "flu_h1n1pdm_na"
                return [[id: params.runid+"_h1n1_na", type: "h1n1", segment: "na"], file]
            h3n2_na: file_name == "flu_h3n2_na"
                return [[id: params.runid+"_h3n2_na", type: "h3n2", segment: "na"], file]
            h0n0_na: file_name == "flu_vic_na"
                return [[id: params.runid+"_h0n0_na", type: "h0n0", segment: "na"], file]
        }

        // formatting channels: collecting all fastas and adding additional information into the meta map
        ch_h1n1_ha = ch_sequences.h1n1_ha.collect().map{ fastas ->
            [[id: params.runid+"_h1n1_ha", type: "h1n1", segment: "ha"], fastas]
        }
        ch_h3n2_ha = ch_sequences.h3n2_ha.collect().map{ fastas ->
            [[id: params.runid+"_h3n2_ha", type: "h3n2", segment: "ha"], fastas]
        }
        ch_h0n0_ha = ch_sequences.h0n0_ha.collect().map{ fastas ->
            [[id: params.runid+"_h0n0_ha", type: "h0n0", segment: "ha"], fastas]
        }
        ch_h1n1_na = ch_sequences.h1n1_na.collect().map{ fastas ->
            [[id: params.runid+"_h1n1_na", type: "h1n1", segment: "na"], fastas]
        }
        ch_h3n2_na = ch_sequences.h3n2_na.collect().map{ fastas ->
            [[id: params.runid+"_h3n2_na", type: "h3n2", segment: "na"], fastas]
        }
        ch_h0n0_na = ch_sequences.h0n0_na.collect().map{ fastas ->
            [[id: params.runid+"_h0n0_na", type: "h0n0", segment: "na"], fastas]
        }

    } else {

        // formatting channels: collecting all fastas and adding additional information into the meta map
        ch_h1n1_ha = ch_sequences.h1n1_ha.collect().map{ fastas ->
            [[id: params.runid+"_h1n1_ha", dataset: params.dataset_h1n1_ha, type: "h1n1", segment: "ha"], fastas]
        }
        ch_h3n2_ha = ch_sequences.h3n2_ha.collect().map{ fastas ->
            [[id: params.runid+"_h3n2_ha", dataset: params.dataset_h3n2_ha, type: "h3n2", segment: "ha"], fastas]
        }
        ch_h0n0_ha = ch_sequences.h0n0_ha.collect().map{ fastas ->
            [[id: params.runid+"_h0n0_ha", dataset: params.dataset_h0n0_ha, type: "h0n0", segment: "ha"], fastas]
        }
        ch_h1n1_na = ch_sequences.h1n1_na.collect().map{ fastas ->
            [[id: params.runid+"_h1n1_na", dataset: params.dataset_h1n1_na, type: "h1n1", segment: "na"], fastas]
        }
        ch_h3n2_na = ch_sequences.h3n2_na.collect().map{ fastas ->
            [[id: params.runid+"_h3n2_na", dataset: params.dataset_h3n2_na, type: "h3n2", segment: "na"], fastas]
        }
        ch_h0n0_na = ch_sequences.h0n0_na.collect().map{ fastas ->
            [[id: params.runid+"_h0n0_na", dataset: params.dataset_h0n0_na, type: "h0n0", segment: "na"], fastas]
        }

    }
    // combine all channels into one
    ch_all = ch_h3n2_ha.mix(ch_h3n2_na).mix(ch_h1n1_ha).mix(ch_h1n1_na).mix(ch_h0n0_ha).mix(ch_h0n0_na)

    // generate multi-fasta files for every type-segment pair
    CAT_CAT(
        ch_all
    )
    ch_merged_sequences = CAT_CAT.out.file_out

    // filter out empty multi-fasta files
    ch_merged_sequences = ch_merged_sequences.branch { _meta, fasta ->
        empty: file(fasta).size() == 0
        not_empty: file(fasta).size() != 0
    }

    if (!params.get_nextclade_dataset) {
        // move the reference datasets to a separate channel
        ch_datasets = ch_merged_sequences.not_empty.map { meta, _fasta -> meta.dataset}

        NEXTCLADE_RUN(
            ch_merged_sequences.not_empty,
            ch_datasets
        )

    } else {

        // "unbranch" the dataset channel to join with the not empty merged sequences
        ch_datasets = ch_datasets.h1n1_ha.mix(ch_datasets.h1n1_na).mix(ch_datasets.h3n2_ha).mix(ch_datasets.h3n2_na).mix(ch_datasets.h0n0_ha).mix(ch_datasets.h0n0_na)
        ch_nextclade_input = ch_merged_sequences.not_empty.join(ch_datasets).multiMap{ meta, fasta, dataset ->
            fasta_input: [meta, fasta]
            dataset: dataset
        }

        // run the Nextclade analyses
        NEXTCLADE_RUN(
            ch_nextclade_input.fasta_input,
            ch_nextclade_input.dataset
        )
    }



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
