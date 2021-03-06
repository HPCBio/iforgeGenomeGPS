#!/bin/sh
######################################
#  script to convert bam files back to fastq as pre requisite to alignment
#
######################################
redmine=hpcbio-redmine@igb.illinois.edu
if [ $# != 7 ];
then
	MSG= "parameter mismatch"
        echo -e "jobid:${PBS_JOBID}\nprogram=$0 stopped at line=$LINENO.\nReason=$MSG" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine""
        exit 1;
else					
	set -x
	echo `date`
        scriptfile=$0
        inputdir=$1
        samplefileinfo=$2
        runfile=$3
        elog=$4
        olog=$5
        email=$6
        qsubfile=$7
        LOGS="jobid:${PBS_JOBID}\nqsubfile=$qsubfile\nerrorlog=$elog\noutputlog=$olog"

        if [ ! -s $runfile ]
        then
	    MSG="$runfile configuration file not found"
            echo -e "program=$0 stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine,$email""
	    exit 1;
        fi

        picardir=$( cat $runfile | grep -w PICARDIR | cut -d '=' -f2 )
        paired=$( cat $runfile | grep -w PAIRED | cut -d '=' -f2 )
        bam2fastqparms=$( cat $runfile | grep -w BAM2FASTQPARMS | cut -d '=' -f2 )
        bam2fastqflag=$( cat $runfile | grep -w BAM2FASTQFLAG | cut -d '=' -f2 )
        multisample=$( cat $runfile | grep -w MULTISAMPLE | cut -d '=' -f2 )
        samples=$( cat $runfile | grep -w SAMPLENAMES | cut -d '=' -f2 )
        samplefileinfo=$( cat $runfile | grep -w SAMPLEFILENAMES | cut -d '=' -f2 )
        javamodule=$( cat $runfile | grep -w JAVAMODULE | cut -d '=' -f2 )
        if [ ! -d $picardir ]
        then
	    MSG="PICARDIR=$picardir  directory not found"
            echo -e "program=$scriptfile stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine,$email""
	    exit 1;
        fi      
        if [ ! -d $inputdir ]
        then
	    MSG="INPUTDIR=$inputdir directory not found"
            echo -e "program=$scriptfile stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine,$email""
	    exit 1;
        fi
        if [ ! -s $samplefileinfo ]
        then
	    MSG="SAMPLEFILENAMES=$samplefileinfo file not found"
            echo -e "program=$scriptfile stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine,$email""
	    exit 1;
        fi
        if [ -z $javamodule ]
        then
	    MSG="Value for JAVAMODULE must be specified in configuration file"
            echo -e "program=$scriptfile stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine,$email""
	    exit 1;
        else 
            `/usr/local/modules-3.2.9.iforge/Modules/bin/modulecmd bash load $javamodule`
        fi


        newnames=""
        cd $inputdir
        while read sampledetail
        do
	    len=`expr ${#sampledetail}`
	    if [ $len -gt 0 ]
            then
		dirname=$( echo $sampledetail | grep ^BAM | cut -d ':' -f2 | cut -d '=' -f1 )
		prefix=$( echo $sampledetail | grep ^BAM | cut -d ':' -f2 | cut -d '=' -f2 )
                if [ ! -s $inputdir/$dirname/$prefix ]
                then
                    MSG="$dirname/$prefix BAM file not found. bam2fastq failed."
            echo -e "program=$scriptfile stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine,$email""
		    exit 1;
                fi

                cd $inputdir/$dirname

		R1=${prefix}_R1.fastq
		R2=${prefix}_R2.fastq

		if [ $paired == "1" ]
                then
		    java -Xmx6g -Xms512m  -jar $picardir/SamToFastq.jar \
			FASTQ=$R1 \
			SECOND_END_FASTQ=$R2 \
			INPUT=$prefix \
			TMP_DIR=$inputdir \
			$bam2fastqparms \
			VALIDATION_STRINGENCY=SILENT 
		    echo `date`
		    if [ ! -s $R1 -o ! -s $R2 ]
		    then
			MSG="$R1 $R2 FASTQ files not created. bam2fastq failed."
            echo -e "program=$scriptfile stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine,$email""
			exit 1;
                    else
			newnames="FASTQ:${dirname}=${R1} ${R2}\n$newnames"
		    fi
                else
		    java -Xmx6g -Xms512m  -jar $picardir/SamToFastq.jar \
			FASTQ=$R1 \
			INPUT=$prefix \
			TMP_DIR=$inputdir \
			$bam2fastqparms \
			VALIDATION_STRINGENCY=SILENT 
		    echo `date`
		    if [ ! -s $R1 ]
		    then
			MSG="$R1 FASTQ file not created. bam2fastq failed."
            echo -e "program=$scriptfile stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | ssh iforge "mailx -s '[Support #200] Mayo variant identification pipeline' "$redmine,$email""
			exit 1;
                    else
			newnames="FASTQ:${dirname}=${R1}\n$newnames"
		    fi
		fi
	    else
                echo "line is empty. $sampledetail"
	    fi
	done < $samplefileinfo

        ## done with the conversion. 
        ## Now generating new sample_info file. We assume the extension is txt

        directory=`dirname $samplefileinfo`
        oldfileprefix=`basename $samplefileinfo .txt`
        newfilename=$directory/$oldfileprefix.old.txt
        oldfilename=$directory/$oldfileprefix.txt
        mv $samplefileinfo $newfilename
        oldname=$( echo  -e $newnames | sed "s/\n\n/\n/g" )
        echo $oldname >> $oldfilename
	echo `date`
fi