rule index_bam:
    input:
         bam = os.path.join(star_outpath, "{sample}", 
            "Aligned.sortedByCoord.out.bam"),
    output:
        bai = os.path.join(star_outpath, "{sample}",
            "Aligned.sortedByCoord.out.bam.bai")

    conda: "../envs/index-bam.yml"
    log: os.path.join(log_path, "index-bam", "{sample}.log")
    params:
        # extra = config['samtools']['extra']
    
    shell:
        """samtools index {input.bam} """