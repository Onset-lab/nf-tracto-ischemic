#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PIPELINE_INITIALISATION } from './subworkflows/local/pipeline_initialisation/main.nf'
include { REGISTRATION_ANTS as REGISTRATION_POSTOP_ON_PREOP } from './modules/nf-neuro/registration/ants/main'
include { REGISTRATION_ANTS as REGISTRATION_REFERENCE_ON_PREOP } from './modules/nf-neuro/registration/ants/main'
include { REGISTRATION_TRACTOGRAM } from './modules/nf-neuro/registration/tractogram/main'
include { BETCROP_ANTSBET } from './modules/nf-neuro/betcrop/antsbet/main'
include { REGISTRATION_ANTSAPPLYTRANSFORMS } from './modules/nf-neuro/registration/antsapplytransforms/main'
include { REGISTRATION_ANTSAPPLYTRANSFORMS as REGISTRATION_BRAINNETOME } from './modules/nf-neuro/registration/antsapplytransforms/main'
include { STREAMLINES_IN_MASK } from './modules/local/streamlines_in_mask/main.nf'
include { MOVE_TO_POSTOP } from './modules/local/move_to_postop/main.nf'
include { LABELS_IN_CAVITY } from './modules/local/labels_in_cavity/main.nf'

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
        params.brainnetome,
        params.output_dir
    )

    ch_postop_preop = PIPELINE_INITIALISATION.out.t1_preop
        .join(PIPELINE_INITIALISATION.out.t1_postop)
        .map{ it + [[]] }
    REGISTRATION_POSTOP_ON_PREOP(ch_postop_preop)

    ch_bet = PIPELINE_INITIALISATION.out.t1_preop
        .merge(PIPELINE_INITIALISATION.out.t1_template.first())
        .merge(PIPELINE_INITIALISATION.out.t1_probability_map.first())
        .map{ it + [[], []] }
    BETCROP_ANTSBET(ch_bet)

    ch_reference_preop = BETCROP_ANTSBET.out.t1
        .combine(PIPELINE_INITIALISATION.out.atlas_reference.first())
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

    ch_move_to_postop = PIPELINE_INITIALISATION.out.avc
        .mix(PIPELINE_INITIALISATION.out.cavite)
        .groupTuple()
        .join(PIPELINE_INITIALISATION.out.t1_postop)
    MOVE_TO_POSTOP(ch_move_to_postop)

    ch_ants_apply_transforms = MOVE_TO_POSTOP.out.warped_image
        .join(PIPELINE_INITIALISATION.out.t1_preop)
        .join(REGISTRATION_POSTOP_ON_PREOP.out.warp)
        .join(REGISTRATION_POSTOP_ON_PREOP.out.affine)
    REGISTRATION_ANTSAPPLYTRANSFORMS(ch_ants_apply_transforms)

    ch_streamlines_in_mask = REGISTRATION_ANTSAPPLYTRANSFORMS.out.warped_image
        .map { it[1] instanceof List && it[1].size() > 1 ? [it[0], it[1][0]] : [] }
        .join(REGISTRATION_TRACTOGRAM.out.warped_tractogram)
    STREAMLINES_IN_MASK(ch_streamlines_in_mask)

    ch_brainnetome = PIPELINE_INITIALISATION.out.t1_preop
        .combine(PIPELINE_INITIALISATION.out.brainnetome)
        .map { [it[0], it[2], it[1]] }.view()
        .join(REGISTRATION_REFERENCE_ON_PREOP.out.warp)
        .join(REGISTRATION_REFERENCE_ON_PREOP.out.affine)
    REGISTRATION_BRAINNETOME(ch_brainnetome)

    ch_labels_in_cavity = REGISTRATION_ANTSAPPLYTRANSFORMS.out.warped_image
        .map { it[1] instanceof List && it[1].size() > 1 ? [it[0], it[1][1]] : it }
        .join(REGISTRATION_BRAINNETOME.out.warped_image)

    LABELS_IN_CAVITY(ch_labels_in_cavity)
}
