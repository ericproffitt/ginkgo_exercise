#!/bin/sh

## Basic SARS-CoV-2 variant calling pipeline.
## GATK Mutect2 works well for viral variant calling.
## see SAMPLE.eff.vcf file for final output.

## REQUIREMENTS:
## sratoolkit
## samtools
## bwa
## gatk
## snpEff (included, as it had to be modified for custom MN908947.3 genome)

## STEPS:
## 1. Download sample FASTQs from SRA.
## 2. Align reads to SARS-CoV-2 reference genome using BWA.
## 3. Convert SAM to BAM and process BAM.
## 4. Variant calling using GATK Mutect2.
## 5. Variant annotation using SnpEff.

## USAGE (default downsampled SARS-CoV-2 sample, SRR15660643):
## bash prompt1.sh

## USAGE (custom SARS-CoV-2 SRA sample):
## bash prompt1.sh -sample <sample>

## Several other SARS-CoV-2 samples to test:
## SRR17497950
## SRR17773164
## SRR17871512

cd $(dirname $0)

while [ $# -gt 0 ]; do
	case $1 in
		-sample)
		SAMPLE=$2
		shift 2
		;;
	esac
done

## Download FASTQ files.
if [[ ! $SAMPLE ]]; then
	SAMPLE=SRR15660643
	FASTQ="SRR15660643.1.16000.fq SRR15660643.2.16000.fq"
else
	fastq-dump --split-files $SAMPLE
	FASTQ=$(ls ${SAMPLE}* | tr '\n' ' ')
fi

rm -rf $SAMPLE 2>/dev/null

## Align sample reads using BWA.
bwa mem MN908947.3/MN908947.3 $(echo $FASTQ) > ${SAMPLE}.sam

## SAM -> BAM
## Fix BAM file for GATK processing.
## Index BAM file.
samtools sort ${SAMPLE}.sam -o ${SAMPLE}.bam
samtools addreplacerg -r "@RG\tID:${SAMPLE}\tSM:${SAMPLE}" ${SAMPLE}.bam -o ${SAMPLE}-fixed.bam
mv ${SAMPLE}-fixed.bam ${SAMPLE}.bam
samtools index ${SAMPLE}.bam

## Variant calling using GATK Mutect2.
gatk Mutect2 \
	-R MN908947.3/MN908947.3.fasta \
	-I ${SAMPLE}.bam \
	-O ${SAMPLE}.vcf.gz

## Variant annotation using SnpEff.
java -jar snpEff/snpEff.jar -c snpEff/snpEff.config MN908947.3 ${SAMPLE}.vcf > ${SAMPLE}.eff.vcf

## Put sample output in SAMPLE directory.
mkdir $SAMPLE
mv ${SAMPLE}*.* $SAMPLE
mv ${SAMPLE}/*q .
mv snpEff_genes.txt $SAMPLE
mv snpEff_summary.html $SAMPLE
