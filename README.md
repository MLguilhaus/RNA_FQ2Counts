# RNA FASTQ to Counts

This Snakemake workflow moves raw paired-end RNA-seq FASTQ files from uofaresstor to Phoenix, verifies integrity via MD5 checksums, trims reads with fastp, aligns with STAR, and generates a count matrix with featureCounts. MultiQC and samtools flagstat are run for QC.

See `dag.pdf` for a visual overview of the full workflow.

---

## Pipeline steps

1. **Transfer** — SCP FASTQ files from uofaresstor to Phoenix (`data/fastq/raw/`)
2. **MD5 verification** — checksums of transferred files are compared against the origin MD5 file
3. **Trimming** — fastp trims adapters and low-quality bases
4. **Alignment** — STAR aligns trimmed reads to the reference genome
5. **Counting** — featureCounts generates a gene-level count matrix across all samples
6. **QC** — MultiQC aggregates fastp, STAR, and flagstat reports

---

## Prerequisites

- **SSH key access** configured on Phoenix (see below — required once per user before running the workflow)
- **STAR genome index** pre-built at the path you will set in `star_ref_path` (the index must be in that same directory)
- **Snakemake** installed (≥7.0 recommended)
- **Conda/mamba** for environment management (`--use-conda` flag required)

### SSH key setup (first-time users)

uofaresstor is only accessible from Phoenix login nodes, not compute nodes. The workflow therefore SSHs from compute nodes back to the login node to transfer files via `scp`. Because Snakemake jobs run non-interactively, this must be passwordless.

Since Phoenix home directories are shared across login and compute nodes via NFS, you only need to add your own public key to your own `authorized_keys` once. Run the following on a Phoenix login node:

```bash
# Generate a key if you don't already have one
ls ~/.ssh/id_ecdsa.pub 2>/dev/null || ssh-keygen -t ecdsa

# Add your public key to your own authorised keys
cat ~/.ssh/id_ecdsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Test that it works (should connect without a password prompt):

```bash
ssh phoenix-login1.adelaide.edu.au echo "SSH key working"
```

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/MLguilhaus/RNA_FQ2Counts
cd RNA_FQ2Counts
```

### 2. Create the sample sheet

Copy `config/test_samples.tsv` as a template. The file must have at least a single column called `Run`, with one sample ID per row. Sample IDs must match the FASTQ filenames on uofaresstor (i.e. the workflow expects `<Run>_R1.fastq.gz` and `<Run>_R2.fastq.gz`).

```
Run
26-01781_S1_L01
26-01782_S2_L01
```

### 3. Configure the workflow

Copy the example config and fill in your paths:

```bash
cp config/config.example.yml config/config.yml
```

Key fields to set:

| Field | Description |
|---|---|
| `samples` | Path to your sample sheet TSV |
| `ssh.host` | Your uofaresstor SSH address (e.g. `a1234567@phoenix-login1.adelaide.edu.au`) |
| `ssh.host_path` | Path to FASTQ files on uofaresstor |
| `ssh.host_md5` | Path to the origin MD5 checksum file on uofaresstor |
| `star.star_ref_path` | Path to directory containing the pre-built STAR index |
| `featureCounts.gtf` | Path to the GTF annotation file (e.g. Gencode primary assembly) |
| `featureCounts.strandedness` | `0` = unstranded, `1` = forward stranded, `2` = reverse stranded |

---

## Running the workflow

Open a screen session and dry run the workflow to check the job graph:

```bash
snakemake -np --use-conda
```

Run on the cluster (adjust profile name as needed):

```bash
snakemake --use-conda --cores <N> --profile <slurm-profile>
```

Phoenix is on a SLURM scheduler, you will need to save a yaml profile file in your home directory to set your preferences for defualt reseources and other default cluster options. An example can be found in this repository named example_slurm_profile.yml.

```--cores <N>``` controls how many concurrent jobs Snakemake will submit to SLURM at once. Snakemake tracks each job's ```threads:``` value against this budget — for example, with ```--cores 16``` and rules using the default ```threads: 1```, up to 16 jobs can run simultaneously. Setting this too low will throttle job submission even when the cluster has capacity.

---

## Outputs

| Path | Contents |
|---|---|
| `output/counts/star_counts.out` | Gene-level count matrix (all samples) |
| `output/counts/star_counts.out.summary` | featureCounts assignment summary |
| `output/multiqc/multiqc.html` | Aggregated QC report |
| `output/fastp/<sample>_fastp.html` | Per-sample fastp report |
| `output/star/<sample>_Log.final.out` | Per-sample STAR alignment summary |
| `output/star/<sample>_samtools.flagstat` | Per-sample flagstat (mapping stats) |
| `output/md5/fq.chk.md5` | MD5 check result (pass/fail) |

---

## Important notes

- **Raw and trimmed FASTQs are temporary** — `data/fastq/raw/` and `data/fastq/trimmed/` files are deleted by Snakemake after downstream steps complete successfully. Only the BAMs and counts are retained.
- **MD5 check and batch subsets** — the MD5 verification compares transferred files against the origin checksum file. If you are running a subset of samples from a larger batch, the origin MD5 file must cover only those samples, otherwise the check will fail. It is recommended to generate a batch-specific MD5 file on uofaresstor and point `ssh.host_md5` to that file.
- **STAR index** — the index must already exist at `star_ref_path`. The workflow does not build it.



