#!/bin/bash

. $(dirname $(readlink -f $0))/../lib/bash/softec-common.sh || exit

# call with a parameter to get a specific config file
include_conf

# set a lockfile... at the end of the script call unlock
get_lock

# Questa funzione viene chiamata in caso di CTRL-C
# Viene inoltre chiamata esplicitamente nella quit
# per fare la stessa pulizia in caso di uscita normale
# 
function clean()
{
    rm -f $CACHEDIR/*
}

# Funzione chiamata alla fine dello script
# restituisce 0 a meno che non gli si passi
# un valore come primo parametro
function clean()
{
    unlock
}


tmp_resp=`mktemp`
CSV_HEADER='CLUSTER,FULL_COLLECTION_NAME,WEBNN,COLLECTION,SIZE'
echo $CSV_HEADER > $OUTPUT_CSV_FILE
COLLECTIONS=`${ZOOKEEPER_CONF} --action=getcollections --noout`
for COLLECTION in $COLLECTIONS
do
    if [[ `echo $COLLECTION` =~ web[0-9]{1,3}-.* ]]; then
        COLLECTION_NAME=`echo $COLLECTION | sed -r -e 's/^web[0-9]{1,3}-//'`
        WEBNN=`echo $COLLECTION | sed -e "s/-${COLLECTION_NAME}//"`
    else
        COLLECTION_NAME=$COLLECTION
        WEBNN=''
    fi
    $CURL "http://${SOLR_ADDRESS}/solr/$COLLECTION/replication?command=details" -o $tmp_resp 2> /dev/null
    COLLECTION_SIZE=`echo "cat //response/lst[@name='details']/str[@name='indexSize']/text()" | xmllint --shell $tmp_resp | grep -v '/ >' | egrep -v '\-\-\-'`
    echo "cluster-liliana,$COLLECTION,$WEBNN,$COLLECTION_NAME,$COLLECTION_SIZE" >> $OUTPUT_CSV_FILE
done
rm -rf $tmp_resp
exit 0
