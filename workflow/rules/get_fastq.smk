import pandas as pd

# Move fastq files from ressstor to working diretcory 
rule get_fq:
    output:
        fq1 = temp(os.path.join(raw_path, "{accession}_R1.fastq.gz")),
        fq2 = temp(os.path.join(raw_path, "{accession}_R2.fastq.gz")),

    params:
        host = config['ssh']['host'],
        host_path = config['ssh']['host_path'],
    log: os.path.join(log_path, "download_fq", "{accession}.log")
    resources:
        runtime = "4h",
    benchmark: os.path.join(log_path, "download_fq", "{accession}.benchmark")
    shell:
        """
        r1_success=0
        for i in {{1..3}}; do
            scp "{params.host}:{params.host_path}/{wildcards.accession}_R1.fastq.gz" {output.fq1} \
            2>> {log} && r1_success=1 && break || sleep 10
        done
        if [ $r1_success -eq 1 ]; then
            echo "✅ Successfully transferred R1 file for {wildcards.accession}." | tee -a {log}
        else
            echo "❌ ERROR: Failed to transfer R1 file for {wildcards.accession}." | tee -a {log}
        fi

        r2_success=0
        for i in {{1..3}}; do
            scp "{params.host}:{params.host_path}/{wildcards.accession}_R2.fastq.gz" {output.fq2} \
            2>> {log} && r2_success=1 && break || sleep 10
        done
        if [ $r2_success -eq 1 ]; then
            echo "✅ Successfully transferred R2 file for {wildcards.accession}." | tee -a {log}
        else
            echo "❌ ERROR: Failed to transfer R2 file for {wildcards.accession}." | tee -a {log}
        fi

        """

# Get md5 from origin
rule download_md5:
    output:
        md5 = os.path.join(md5_outpath, "fq_origin.md5"),
    params:
        host = config['ssh']['host'],
        host_path = config['ssh']['host_path'],
        host_md5 = config['ssh']['host_md5']
    log: os.path.join(log_path, "download_md5", "origin.log")
    resources:
        # partition = "dm"
    shell:
        """
        # Retry logic for checksums file
        md5_success=0
        for i in {{1..3}}; do
            scp "{params.host}:{params.host_md5}" {output.md5} > {log} 2>&1 && md5_success=1 && break || sleep 10
        done
        if [ $md5_success -eq 1 ]; then
            echo "✅ Successfully transferred checksums.md5 file for {params.host_md5}." | tee -a {log}
        else
            echo "❌ ERROR: Failed to transfer checksums.md5 file for {params.host_md5}." | tee -a {log}
        fi
        
        """


# Generate md5 for newly moved files
rule gen_md5:
    input:
        fq = expand(os.path.join(raw_path, "{id}_{r}.fastq.gz"), 
        id = accessions, 
        r = ['R1', 'R2'])

    output:
        md5 = os.path.join(md5_outpath, "fq_txfer.md5")
    log: os.path.join(log_path, "gen_md5", "txfer.log")
    shell:
        """
        # Create or truncate the output file
        > {output.md5}
        
        # Calculate MD5 sums for all input files
        for f in {input.fq}; do
            # Get just the filename without path
            filename=$(basename "$f")
            # Calculate MD5 and format output
            md5sum "$f" | awk -v fname="$filename" '{{print $1 " " fname}}' >> {output.md5}
        done
        """

# Check that sums match
# Note: this will only work if the checksums/md5 copied from origin cover all the files being run through the pipeline
# In the instance you are running a batch/subset of samples, the md5 portions of this workflow will likely not work 
# We reccomend generating batchwise md5 sums and pointing to that file in the ssh section of your config 
rule check_md5:
    input:
        txfer_md5 = os.path.join(md5_outpath, "fq_txfer.md5"),
        origin_md5 = os.path.join(md5_outpath,  "fq_origin.md5"),
    output:
        chk = os.path.join(md5_outpath, "fq.chk.md5"),
        origin_norm = temp(os.path.join(md5_outpath, "origin.normalised.md5")),
        txfer_norm = temp(os.path.join(md5_outpath, "txfer.normalised.md5")),
    log: os.path.join(log_path, "check_md5", "fq.md5.log")
    shell:
        """
        # Create normalised versions of both files 
        # (remove asterisk innfont of filename for origin md5s, sort by filename)
        awk '{{print $1, $2}}' {input.txfer_md5} | sort -k2 > {output.txfer_norm}
        awk '{{print $1, substr($2, 2)}}' {input.origin_md5} | sort -k2 > {output.origin_norm}

        # Compare the normalised files
        echo "Checking MD5 sums..." > {output.chk}
        
        # Check if files are identical
        if cmp -s {output.txfer_norm} {output.origin_norm}; then 
            echo "✅ All MD5 sums matched successfully" >> {output.chk}
            echo "Total files checked: $(wc -l < {output.txfer_norm})" >> {output.chk}
        else
            echo "❌ MD5 sums did not match" >> {output.chk}
            echo -e "\\nDifferences found:" >> {output.chk}
            echo "Files with different MD5 sums:" >> {output.chk}
            diff {output.txfer_norm} {output.origin_norm} >> {output.chk} 2>&1
            echo -e "\\nFiles in txfer.md5 but not in origin.md5:" >> {output.chk}
            comm -23 {output.txfer_norm} {output.origin_norm} >> {output.chk} 2>&1
            echo -e "\\nFiles in origin.md5 but not in txfer.md5:" >> {output.chk}
            comm -13 {output.txfer_norm} {output.origin_norm} >> {output.chk} 2>&1
            exit 1
        fi

        """

