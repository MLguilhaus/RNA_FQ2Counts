rule multiqc:
    input:
        trim = ALL_FP,
        align = ALL_BAM,
        star_logs = ALL_STARLOGS,
        flagstat = ALL_FLAGSTAT,
        counts = ALL_COUNTS
    output:
        os.path.join(qc_path, "multiqc.html")
    conda: "../envs/multiqc.yml"
    threads: 1
    params:
        extra = config['multiqc']['extra'],
        run_dir = multi_qc_path,
        outdir = os.path.join(qc_path,)
    log: "workflow/logs/multiqc/multiqc.log"
    resources:
        runtime="15m"
    shell:
        """
        multiqc \
          {params.extra} \
          --force \
          -v \
          --dirs-depth 4 \
          -o {params.outdir} \
          -n multiqc.html \
          {params.run_dir} 2>> {log}
        """