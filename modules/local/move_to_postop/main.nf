process MOVE_TO_POSTOP {
    tag "$meta.id"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "https://scil.usherbrooke.ca/containers/scilus_latest.sif":
        "scilus/scilus:19c87b72bcbc683fb827097dda7f917940fda123"}"

    input:
    tuple val(meta), path(image), path(reference)

    output:
    tuple val(meta), path("*_postop.nii.gz")                           , emit: warped_image
    path "versions.yml"                                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    def output_dtype = task.ext.output_dtype ? "-u " + task.ext.output_dtype : ""
    def dimensionality = task.ext.dimensionality ? "-d " + task.ext.dimensionality : "-d 3"
    def image_type = task.ext.image_type ? "-e " + task.ext.image_type : "-e 0"
    def interpolation = task.ext.interpolation ? "-n " + task.ext.interpolation : ""
    def default_val = task.ext.default_val ? "-f " + task.ext.default_val : ""

    """
    export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$task.cpus
    export OMP_NUM_THREADS=1
    export OPENBLAS_NUM_THREADS=1

    for image in $image;
        do \
        ext=\${image#*.}
        bname=\$(basename \${image} .\${ext})

        antsApplyTransforms $dimensionality\
                            -i \$image\
                            -r $reference\
                            -o ${prefix}__\${bname}_postop.nii.gz\
                            $interpolation\
                            $output_dtype\
                            $image_type\
                            $default_val
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ants: \$(antsRegistration --version | grep "Version" | sed -E 's/.*v([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/')
        mrtrix: \$(mrinfo -version 2>&1 | sed -n 's/== mrinfo \\([0-9.]\\+\\).*/\\1/p')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def suffix = task.ext.first_suffix ? "${task.ext.first_suffix}__warped" : "__warped"

    """
    antsApplyTransforms -h

    for image in $image;
        do \
        ext=\${image#*.}
        bname=\$(basename \${image} .\${ext})

        touch ${prefix}__\${bname}${suffix}.nii.gz
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ants: \$(antsRegistration --version | grep "Version" | sed -E 's/.*v([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/')
        mrtrix: \$(mrinfo -version 2>&1 | sed -n 's/== mrinfo \\([0-9.]\\+\\).*/\\1/p')
    END_VERSIONS
    """
}
