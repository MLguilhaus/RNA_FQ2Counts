
rule feature_counts_star:
    input:
        bam = expand(
            os.path.join(star_outpath, "{sample}", "{bam}"),
            bam = ["Aligned.sortedByCoord.out.bam"],
            sample = accessions
        ),
        bai = expand(
            os.path.join(star_outpath, "{sample}", "{bai}"),
            bai = ["Aligned.sortedByCoord.out.bam.bai"],
            sample = accessions
        ),

        gtf = config['featureCounts']['gtf']
    output:
        counts = os.path.join(fcount_path, "star_counts.out"),
        summary = os.path.join(fcount_path, "star_counts.out.summary")
    conda: "../envs/feature-counts.yml"
    log: os.path.join(log_path, "feature_counts", "star_feature_counts.log")
    threads: 16
    resources:
        runtime = "10h",
        mem_mb = 120000,
        disk_mb = 10000
    params:
        minOverlap = config['featureCounts']['minOverlap'],
        fracOverlap = config['featureCounts']['fracOverlap'],
        q = config['featureCounts']['minQual'],
        s = config['featureCounts']['strandedness'],
        extra = config['featureCounts']['extra']
    shell:
       """
       featureCounts \
         {params.extra} \
         -Q {params.q} \
         -s {params.s} \
         --minOverlap {params.minOverlap} \
         --fracOverlap {params.fracOverlap} \
         -T {threads} \
         -a {input.gtf} \
         -o {output.counts} \
         {input.bam} &>> {log}
       """