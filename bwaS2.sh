#!/bin/sh
redmine=hpcbio-redmine@igb.illinois.edu
if [ $# != 14 ]
then
        MSG="parameter mismatch"
        echo -e "jobid:${PBS_JOBID}\nprogram=$0 stopped at line=$LINENO.\nReason=$MSG" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine""
        exit 1;
else
	set -x
	echo `date`
        scriptfile=$0
        alignerdir=$1
        ref=$2
	outputdir=$3
        R1=$6
        R2=$7
        A1=$4
        A2=$5
        samfile=$8
        bamfile=$9
        samdir=${10}
        elog=${11}
        olog=${12}
        email=${13}
        qsubfile=${14}
        LOGS="jobid:${PBS_JOBID}\nqsubfile=$qsubfile\nerrorlog=$elog\noutputlog=$olog"

        cd $outputdir
        $alignerdir/bwa sampe $ref $A1 $A2 $R1 $R2 > $outputdir/$samfile
        if [ ! -s $outputdir/$samfile ]
        then
            MSG="$outputdir/$samfile aligned file not created. alignment failed"
	   echo -e "program=$scriptfile stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine,$email""
            exit 1;
        fi
        echo `date`
        ## sam2bam conversion
	$samdir/samtools view -bS -o $bamfile $samfile
	if [ ! -s $outputdir/$bamfile ]
	then
	    MSG="$outputdir/$bamfile bam file not created. sam2bam step failed during alignment."
	    echo -e "program=$scriptfile stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine,$email""
	    exit 1;
	fi       
        echo `date`
fi

