#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIPELINE_INITIALISATION } from './subworkflows/local/pipeline_initialisation/main.nf'
include { REGISTRATION_ANTS as REGISTRATION_POSTOP_ON_PREOP } from './modules/nf-neuro/registration/ants/main'
include { REGISTRATION_ANTS as REGISTRATION_REFERENCE_ON_PREOP } from './modules/nf-neuro/registration/ants/main'
include { REGISTRATION_TRACTOGRAM } from './modules/nf-neuro/registration/tractogram/main'
include { BETCROP_ANTSBET } from './modules/nf-neuro/betcrop/antsbet/main'

if(params.help) {
    usage = file("$baseDir/USAGE")

    cpu_count = Runtime.runtime.availableProcessors()
    bindings = ["output_dir":"$params.output_dir"]

    engine = new groovy.text.SimpleTemplateEngine()
    template = engine.createTemplate(usage.text).make(bindings)

    print template.toString()
    return
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.input,
        params.bundle_atlas,
        params.atlas_reference,
        params.t1_template,
        params.output_dir
    )

    ch_postop_preop = PIPELINE_INITIALISATION.out.t1_preop
        .join(PIPELINE_INITIALISATION.out.t1_postop)
        .map{ it + [[]] }
    REGISTRATION_POSTOP_ON_PREOP(ch_postop_preop)

    ch_bet = PIPELINE_INITIALISATION.out.t1_preop
        .merge(PIPELINE_INITIALISATION.out.t1_template)
        .merge(PIPELINE_INITIALISATION.out.t1_probability_map)
        .map{ it + [[], []] }
    BETCROP_ANTSBET(ch_bet)

    ch_reference_preop = BETCROP_ANTSBET.out.t1
        .combine(PIPELINE_INITIALISATION.out.atlas_reference)
        .join(BETCROP_ANTSBET.out.mask)
    REGISTRATION_REFERENCE_ON_PREOP(ch_reference_preop)

    ch_registered_tractogram = PIPELINE_INITIALISATION.out.t1_preop
        .join(REGISTRATION_REFERENCE_ON_PREOP.out.affine)
        .merge(PIPELINE_INITIALISATION.out.bundle_atlas.collect().map{[it]})
        .map{ it + [[]] }
        .join(REGISTRATION_REFERENCE_ON_PREOP.out.inverse_warp)
    REGISTRATION_TRACTOGRAM (
        ch_registered_tractogram
    )
}
