rule multiqc:
    input:
        expand(
            os.path.join(fastp_outpath, "{accession}_fastp.json"),
            accession = accessions
        )
    output:
        os.path.join(qc_path, "multiqc.html")
    conda: "../envs/multiqc.yml"
    threads: 1
    params:
        extra = config['multiqc']['extra'],
        outdir = os.path.join(qc_path,)
    log: "workflow/logs/multiqc/multiqc.log"
    resources:
        runtime="15m"
    shell:
        """
        multiqc \
          {params.extra} \
          --force \
          -o {params.outdir} \
          -n multiqc.html \
          {input} 2> {log}
        """