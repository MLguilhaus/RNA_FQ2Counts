rule fastp:
    input: 
        fq1 = os.path.join(raw_path, "{accession}_R1.fastq.gz"),
        fq2 = os.path.join(raw_path, "{accession}_R2.fastq.gz"),
    output:
        fq1 = temp(os.path.join(trim_path, "{accession}_R1.fastq.gz")),
        fq2 = temp(os.path.join(trim_path, "{accession}_R2.fastq.gz")),
        html = os.path.join(fastp_outpath, "{accession}_fastp.html"),
        json = os.path.join(fastp_outpath, "{accession}_fastp.json"),
    params:
        average_qual = config['fastp']['average_qual'],
        cut_mean_quality = config['fastp']['cut_mean_quality'],
        length_required = config['fastp']['length_required'],
        n_base_limit = config['fastp']['n_base_limit'],
        extra = config['fastp']['extra'],
    conda: "../envs/fastp.yml"
    log: os.path.join(log_path, "fastp", "{accession}.log")
    threads: 4
    resources:
        runtime="2h",
        mem_mb = 4096
    shell:
        """
        fastp \
            --thread {threads} \
            --n_base_limit {params.n_base_limit} \
            --average_qual {params.average_qual} \
            --cut_front \
            --cut_mean_quality {params.cut_mean_quality} \
            --length_required {params.length_required} \
            {params.extra} \
            -i {input.fq1} \
            -I {input.fq2} \
            -o {output.fq1} \
            -O {output.fq2} \
            -h {output.html} \
            -j {output.json} &> {log}
        """

rule trimmed_md5sums:
    input: 
        expand(
            os.path.join(trim_path, "{sample}{tag}.fastq.gz"),
            sample = accessions, 
            tag = ['_R1', '_R2']
        )
    output: 
        os.path.join(trim_path, "md5sums.txt")
    threads: 1
    resources:
        runtime="20m"
    shell:
        """
        md5sum {input} > {output}
        """
