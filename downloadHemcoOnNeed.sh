#!/bin/bash

RUN_DIR=$1
HEMCO_CONF=$RUN_DIR/HEMCO_Config.rc
echo $HEMCO_CONF

if [ -e $HEMCO_CONF ];then
	grep "ROOT" $HEMCO_CONF|egrep "^([0-9]+|[*])" | awk '{print $3}'|egrep "^.ROOT" |sed 's/$ROOT/HEMCO/g' | while read line; do
		echo "Downloading $line"
		wget -r --cut-dir=4 "ftp://ftp.as.harvard.edu/gcgrid/data/ExtData/$line"
	done
fi

#ln -s ftp.as.harvard.edu/* $GC_HOME/ExtData/HEMCO/
