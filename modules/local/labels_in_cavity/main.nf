process LABELS_IN_CAVITY {
    tag "$meta.id"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:2.0.2' }"

    input:
    tuple val(meta), path(mask), path(labels)

    output:
    tuple val(meta), path("*__labels_in_cavity.txt"), emit: labels_in_cavity
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    get_ids.py ${labels} ${mask} > ${prefix}__labels_in_cavity.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fsl
        ants
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ImageMath -h
    fslstats -h

    touch ${prefix}__labels_in_cavity.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fsl
        ants
    END_VERSIONS
    """
}
