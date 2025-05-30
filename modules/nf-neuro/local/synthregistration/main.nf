process REGISTRATION_SYNTHREGISTRATION {
    tag "$meta.id"
    label 'process_high'

    container "freesurfer/synthmorph:4"
    containerOptions {
        (workflow.containerEngine == 'docker' && task.ext.gpu) ? '--entrypoint "" --gpus all' : "--nv"
    }

    input:
    tuple val(meta), path(moving), path(fixed)

    output:
    tuple val(meta), path("*__output_warped.nii.gz")        , emit: warped_image
    tuple val(meta), path("*__deform_warp.nii.gz")          , emit: warp, optional: true
    tuple val(meta), path("*__affine.lta")                  , emit: affine, optional: true
    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    def transform_type = task.ext.transform ? task.ext.transform : "joint"
    def gpu = task.ext.gpu ? "-g" : ""
    def lambda = task.ext.lambda ? "-r " + task.ext.lambda : "-r 0.5"
    def steps = task.ext.steps ? "-n " + task.ext.steps : "-n 7"
    def extent = task.ext.extent ? "-e " + task.ext.extent : "-e 256"
    def weight = task.ext.weight ? "-w " + task.ext.weight : ""
    def transform = task.ext.transform_type == "joint" ? "deform_warp.nii.gz" : "affine.lta"
    """
    export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1
    export OMP_NUM_THREADS=1
    export OPENBLAS_NUM_THREADS=1
    mri_synthmorph register -j $task.cpus -m ${transform_type} ${gpu} ${lambda} ${steps} ${extent} ${weight} -t ${prefix}__${transform} $moving $fixed -o ${prefix}__warped.nii.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        synthmorph: 4
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    mri_synthmorph -h

    touch ${prefix}__output_warped.nii.gz
    touch ${prefix}__deform_warp.nii.gz
    touch ${prefix}__affine_warp.lta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        synthmorph: 4
    END_VERSIONS
    """
}