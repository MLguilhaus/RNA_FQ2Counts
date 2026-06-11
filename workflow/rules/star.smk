rule star_align:
    input:
        r1 = rules.fastp.output.fq1,
        r2 = rules.fastp.output.fq2,
    output:
        bam = os.path.join(
            star_outpath, "{accession}", 
            "Aligned.sortedByCoord.out.bam"
        ),
        star_log = os.path.join(
            star_outpath, "{accession}", "Log.final.out"
        ),
        sj_out = os.path.join(
            star_outpath, "{accession}", "SJ.out.tab"
        ),
        temp_log = os.path.join(
            star_outpath, "{accession}", "Log.out"
        )
    conda: "../envs/star.yml"
    log: os.path.join(log_path, "star_align", "{accession}.log") 
    params:
        index = config['star']['star_ref_path'],
        out_prefix = os.path.join(star_outpath, "{accession}", ""),
        out_samtype = config['star']['out_samtype'],
        out_samattributes = config['star']['out_samattributes'],
        out_samunmapped = config['star']['out_samunmapped'],
        multimap_nmax = config['star']['multimap_nmax'],
        mismatch_nmax = config['star']['mismatch_nmax'],
        temp_dir = os.path.join(
            star_outpath, "{accession}", "_STARtmp"
        )
    threads: 8
    resources:
        runtime = "3h",
        mem_mb = 32768
    shell:
        """
        STAR \
          --runThreadN {threads} \
          --genomeDir {params.index} \
          --readFilesIn {input.r1} {input.r2} \
          --readFilesCommand zcat \
          --outSAMtype {params.out_samtype} \
          --outSAMattributes {params.out_samattributes} \
          --outSAMunmapped {params.out_samunmapped} \
          --outFilterMultimapNmax {params.multimap_nmax} \
          --outFilterMismatchNmax {params.mismatch_nmax} \
          --outFileNamePrefix {params.out_prefix} \
          --outStd Log &>> {log}
        
        ## Deleting this here ensures it is **retained on failure**, but
        ## removed on success as it is entirely redundant at that point
        echo -e "Deleting Log.progress.out"
        rm -f {params.out_prefix}/Log.progress.out

        ## Cleanup the temp_dir
        if [[ -d {params.temp_dir} ]]; then
            echo -e "Deleting {params.temp_dir}" >> {log}
            rm -rf {params.temp_dir}
        fi
        """

#### useful to have with git, more notes in physical notes
rule copy_star_logs:
    input:
        star_log = rules.star_align.output.star_log,
        sj_out = rules.star_align.output.sj_out
    output:
        star_log = os.path.join(
            starlog_path, "{accession}_Log.final.out"
        ),
        sj_out = os.path.join(
            starlog_path, "{accession}_SJ.out.tab"
        )
    threads: 1
    resources:
        runtime = "1m"
    shell:
        """
        cp {input.star_log} {output.star_log}
        cp {input.sj_out} {output.sj_out}
        """

### Additional QC Gives stats on primary mapped, secondary mapped, duplicates etc
rule star_flagstat:
    input: 
        bam = os.path.join(
            star_outpath, "{accession}",
            "Aligned.sortedByCoord.out.bam"
        ),
        bai = os.path.join(
            star_outpath, "{accession}", 
            "Aligned.sortedByCoord.out.bam.bai"
        )
    output:
        os.path.join(
            starlog_path, "{accession}_samtools.flagstat"
        )
    conda: "../envs/samtools.yml"
    threads: 4
    resources:
        runtime = "30m"
    shell:
        """
        samtools flagstat -@ {threads} {input.bam} > {output}
        """

rule star_md5sums:
    input:
        expand(
            os.path.join(
                star_outpath, "{sample}",
                "Aligned.sortedByCoord.out.bam"
            ),
            sample = accessions
        )
    output:
        os.path.join(md5_outpath, "star_origin.md5")
    threads: 1
    resources:
        runtime="20m"
    shell:
        """
        md5sum {input} > {output}
        """