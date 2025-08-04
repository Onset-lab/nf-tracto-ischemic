process STREAMLINES_IN_MASK {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:2.0.2' }"

    input:
    tuple val(meta), path(mask), path(bundles)

    output:
    tuple val(meta), path("*__bundles_in_avc"), emit: bundles_in_avc
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    for bundle in ${bundles};
        do \
        ext=\${bundle#*.}
        bname=\$(basename \${bundle} .\${ext})

        scil_tractogram_filter_by_roi.py "\${bundle}" tmp.trk \
            --drawn_roi "${mask}" any include -f --display_counts > tmp.json

        nb_tot_streamlines=$(jq '.streamline_count_before_filtering' tmp.json)
        nb_filtered_streamlines=$(jq '.streamline_count_final_filtering' tmp.json)
        perc_in_avc=$(echo "scale=4; $nb_filtered_streamlines / $nb_tot_streamlines" | bc)

        jq -n \
            --arg sid "${prefix}" \
            --arg nb_tot_streamlines "$nb_tot_streamlines" \
            --arg nb_filtered_streamlines "$nb_filtered_streamlines" \
            --arg perc_in_avc "$perc_in_avc" \
            '{sid: $sid, nb_tot_streamlines: $nb_tot_streamlines, nb_filtered_streamlines: $nb_filtered_streamlines, perc_in_avc: $perc_in_avc}' > \${bname}.json
        rm -f tmp.trk tmp.json
    done

    jq -s '.' *.json > ${prefix}__bundles_in_avc.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: 2.0.2
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    scil_tractogram_filter_by_roi.py -h

    touch ${prefix}__bundles_in_avc.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: 2.0.2
    END_VERSIONS
    """
}
