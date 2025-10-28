
def logoHeader(){
    // Log colors ANSI codes
    c_reset = "\033[0m";
    c_dim = "\033[2m";
    c_blue = "\033[0;34m";

    return """
    ${c_dim}-----------------------------------${c_reset}
    ${c_blue}    ___  _   _ ____  _____ _____   ${c_reset}
    ${c_blue}   / _ \\| \\ | / ___|| ____|_   _|  ${c_reset}
    ${c_blue}  | | | |  \\| \\___ \\|  _|   | |    ${c_reset}
    ${c_blue}  | |_| | |\\  |___) | |___  | |    ${c_reset}
    ${c_blue}   \\___/|_| \\_|____/|_____| |_|    ${c_reset}

    ${c_dim}------------------------------------${c_reset}
    """.stripIndent()
}

log.info logoHeader()

log.info "\033[0;33m ${workflow.manifest.name} \033[0m"
log.info "  ${workflow.manifest.description}"
log.info "  Version: ${workflow.manifest.version}"
log.info "  Github: ${workflow.manifest.homePage}"
log.info " "

workflow.onComplete {
    log.info " "
    log.info "Pipeline completed at: $workflow.complete"
    log.info "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
    log.info "Execution duration: $workflow.duration"
}

workflow PIPELINE_INITIALISATION {

    take:
    input              // path
    bundle_atlas       // path
    atlas_reference    // path
    t1_template        // path
    brainnetome        // path
    outdir             // path

    main:

    if (!input || !bundle_atlas || !atlas_reference || !t1_template) {
        log.error"""Missing required parameters:
        - input: ${input}
        - bundle_atlas: ${bundle_atlas}
        - atlas_reference: ${atlas_reference}
        - t1_template: ${t1_template}
        """
        exit 1
    }
    
    t1_preop_channel = Channel.fromPath("$input/**/*t1_preop.nii.gz")
                        .map{ch1 ->
                            def fmeta = [:]
                            // Set meta.id
                            fmeta.id =  ch1.parent.name
                            [fmeta, ch1]
                        }
    t1_postop_channel = Channel.fromPath("$input/**/*t1_postop.nii.gz")
                        .map{ch1 ->
                            def fmeta = [:]
                            // Set meta.id
                            fmeta.id =  ch1.parent.name
                            [fmeta, ch1]
                        }
    avc_channel = Channel.fromPath("$input/**/avc.nii.gz")
                    .map{ch1 ->
                        def fmeta = [:]
                        // Set meta.id
                        fmeta.id =  ch1.parent.name
                        [fmeta, ch1]
                    }
    
    cavite_channel = Channel.fromPath("$input/**/cavite.nii.gz")
                    .map{ch1 ->
                        def fmeta = [:]
                        // Set meta.id
                        fmeta.id =  ch1.parent.name
                        [fmeta, ch1]
                    }
    
    brainnetome_channel = Channel.fromPath("$input/**/brainnetome.nii.gz")
                    .map{ch1 ->
                        def fmeta = [:]
                        // Set meta.id
                        fmeta.id =  ch1.parent.name
                        [fmeta, ch1]
                    }

    atlas_reference_channel = Channel.fromPath("$atlas_reference")
    bundle_atlas_channel = Channel.fromPath("$bundle_atlas/*.trk")
    t1_template_channel = Channel.fromPath("$t1_template/t1_template.nii.gz")
    t1_probability_map_channel = Channel.fromPath("$t1_template/t1_brain_probability_map.nii.gz")

    log.info "\033[0;33m Parameters \033[0m"
    log.info " Input: ${input}"
    log.info " Bundle atlas: ${bundle_atlas}"
    log.info " Atlas reference: ${atlas_reference}"
    log.info " Brainnetome: ${brainnetome}"
    log.info " Output directory: ${outdir}"

    emit:
    t1_preop = t1_preop_channel        // channel: [ val(meta), [ image ] ]
    t1_postop = t1_postop_channel        // channel: [ val(meta), [ image ] ]
    avc = avc_channel                // channel: [ val(meta), [ image ] ]
    cavite = cavite_channel            // channel: [ val(meta), [ image ] ]
    brainnetome = brainnetome_channel    // channel: [ val(meta), [ image
    bundle_atlas = bundle_atlas_channel        // channel: [ paths ]
    atlas_reference = atlas_reference_channel  // channel: [ path ]
    t1_template = t1_template_channel        // channel: [ path ]
    t1_probability_map = t1_probability_map_channel // channel: [ path ]
}
