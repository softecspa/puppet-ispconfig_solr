#!/bin/bash

LOGLEVEL=$LOGLEVEL_DEBUG

. $(dirname $(readlink -f $0))/../lib/bash/softec-common.sh || exit

# Load configuration from default path
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

# Classica funzione che spiega la sintassi
function help()
{
    echo -e "Usage: `basename $0` --action=<action> --collection=<collection> [OPTIONS]\n
`basename $0` manage creation|deletion of solr cloud collections. It manage also configuration management through zookeeper

    OPTIONS:
    -a|--action:\t action to perform. Available value are <create|delete>
    -w|--webnn:\t\t It indicate the ispconfig webNN that will use the collection. If cwd is $ROOT_DIR/webNN, you don't need to specify it: webNN will be used
    -c|--collection:\t name of collection to create|delete. NOTE: if --action=create a webNN- suffix will be added if it's not already present in collection name.
    \t\t\t Example: --action=create --webnn=web10 --collection=example will create a collection named web10-example
    \t\t\t\t  --action=create --collection=web10-example will create a collection named web10-example
    \t\t\t\t  --action=delete --collection=web10-example will delete collection named web10-example
    --confname:\t\t name for the config that will be created under zookeeper. Don't use in conjuction with -u|--useconf
    --confdir:\t\t directory containing collection's xml configuration files. Files will be uploaded to zookeeper and associated to config name specified in --confname.
    \t\t\t If it's not specified this script will find it in
    \t\t\t\t  - ${ROOT_DIR}/\$webNN/conf/\$confname
    \t\t\t\t  - ${SHARED_XML_CONFIG}/\$confname
    -u|--useconf:\t name of already created config to use for this collection (for example you can use the same configs for all drupal7 sites)
    -s|--shards:\t number of shards to create for this collection. Default: 1
    --replica:\t\t replication factor. Default: 2
    -h|--help:\t\t print this help and exit\n\n"
    exit 0
}

# Funzione chiamata alla fine dello script
# restituisce 0 a meno che non gli si passi
# un valore come primo parametro
function clean()
{
    unlock
}

TEMP=`getopt -o :a:w:c:s:dh --long action:,webnn:,collection:,useconf:,confdir:,confname:,shards:,replica:,debug,help -n "$0" -- "$@"`
log "`whoami` Start with following arguments: ${TEMP}"

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true; do
  case "$1" in
    -d | --debug )
        DEBUG=1
        setloglevel 3
        shift 1
        ;;
    -a | --action )
        if [ $2 != 'create' ] && [ $2 != 'delete' ]; then
            log_error "Error: undefined action $2"
            exit 1
        else
            ACTION=$2
        fi
        shift 2
        ;;
    -w | --webnn )
        if [[ ! $2 =~ web[0-9]{1,3}$ ]]; then
            log_error "Error: incorrect webNN"
            exit 1
        else
            WEBNN=$2
            shift 2
        fi
        ;;
    -c | --collection )
        COLLECTION=$2
        shift 2
        ;;
    -u | --useconf )
        if [ "x${CONFNAME}" != "x" ]; then
            log_error "--useconf cannot be used in conjuction with --confname"
            exit 1
        fi
        CONFNAME=$2
        USECONF=1
        shift 2
        ;;
    --confdir )
        if [ -f $2/schema.xml ] && [ -f $2/solrconfig.xml ]; then
            CONFDIR=$2
        else
            log_error "$2 is not a valid confdir. $2/schema.xml and/or $2/solrconfig.xml not exists"
            exit 1
        fi
        shift 2
        ;;
    --confname )
        if [ "x${CONFNAME}" != "x" ]; then
            log_error "--confname cannot be used in conjuction with --useconf"
            exit 1
        fi
        CONFNAME=$2
        shift 2
        ;;
    -s | --shards)
        if [[ `echo $2` =~ [0-9] ]]; then
            SHARDS=$2
        else
            log_error "--shards value must be integer"
            exit 1
        fi
        shift 2
        ;;
    --replica)
        if [[ `echo $2` =~ [0-9] ]]; then
            REPLICA=$2
        else
            log_error "--replica value must be integer"
            exit 1
        fi
        shift 2
        ;;
    -h | --help)
        help
        exit
        shift 2
        ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

# if no webnn specified and cwd is a webNN, this webNN is used
if [ "x${WEBNN}" == "x" ]; then
    if [[ `$PWD` =~ /var/www/(web[0-9]{1,3})(/.*)?$ ]]; then
        WEBNN=`${PWD} | cut -d/ -f4`
        log_debug "`$PWD` match webNN, $WEBNN will be used"
    fi
fi

### mandatory params ###################
if [ "x$ACTION" == "x" ]; then
    log_error "parameter --action|-a is mandatory"
    exit 1
else
    if [ "$ACTION" == "create" ]; then
        if [ "x$WEBNN" == "x" ]; then
            log_error "webnn is mandatory in action ${ACTION}. You can use --webnn|-w parameter or launch this script under a ${ROOT_DIR}/webNN"
            exit 1
        fi
        if [ "x$CONFNAME" == "x" ]; then
            log_error "--confname or --useconf is mandatory in action ${ACTION}"
            exit 1
        fi
    fi
fi

if [ "x$COLLECTION" == "x" ]; then
    log_error "parameter --collection|-c is mandatory"
    exit 1
fi
#######################################

tmp_resp=`mktemp`
log_debug "created temporary file $tmp_resp"
if [ $ACTION == 'delete' ]; then
        get_confirm "[*] You are going do delete collection ${COLLECTION}, all data will be erased. Are you sure? [S/N]"
        # Eseguo la cancellazione
        log "deleting collection ${COLLECTION}"
        $CURL "http://${SOLR_ADDRESS}/solr/admin/collections?action=DELETE&name=${COLLECTION}" -o $tmp_resp 2> /dev/null
else
    # se il nome specificato per la collection non ha il prefisso webNN lo aggiungo
    if [[ `echo $COLLECTION` =~ web[0-9]{1,3}-.* ]]; then
        COLLECTION_NAME=$COLLECTION
    else
        log_debug "add prefix ${WEBNN}- before collection name"
        COLLECTION_NAME="${WEBNN}-${COLLECTION}"
    fi
    log_debug "collection name will be $COLLECTION_NAME"
    # se l'utente ha specificato una conf gia esistente
    if [ $USECONF == 1 ]; then
        # controllo che la conf indicata esista
        ${ZOOKEEPER_CONF} --action=check --confname=${CONFNAME}
        if [ $? -eq 0 ]; then
            get_confirm "[*] Collection named ${COLLECTION_NAME} will be created using config ${CONFNAME}. Shards: ${SHARDS}, ReplicationFactor: ${REPLICA}. Do you confirm [S/N]?"
            log "creating collection {$COLLECTION_NAME} using conf ${CONFNAME}"
            $CURL "http://${SOLR_ADDRESS}/solr/admin/collections?action=CREATE&name=${COLLECTION_NAME}&numShards=${SHARDS}&replicationFactor=${REPLICA}&collection.configName=${CONFNAME}" -o $tmp_resp 2> /dev/null
        else
            log_error "Config named ${CONFNAME} not exists"
            exit 1
        fi
    else
        if [ "x$CONFDIR" == "x" ]; then
            # se non è stata specificata una directory con le conf analizza, in ordine:
            #   * /var/www/webNN/conf/${CONFNAME}
            #   * /usr/local/etc/solr_xml_config/${CONFNAME}
            # nella variabile ORIGINS i path dove controllare che esistano le conf
            ORIGINS="/var/www/${WEBNN}/conf/${CONFNAME} ${SHARED_XML_CONFIG}/${CONFNAME}"
            for ORIGIN in `echo $ORIGINS`; do
                log_debug "check ${ORIGIN} for confdir"
                if [ -d $ORIGIN ]; then
                    log_debug "${ORIGIN} exists. searching for schema.xml and solrconfig.xml"
                    if [ -f ${ORIGIN}/schema.xml ] && [ -f ${ORIGIN}/solrconfig.xml ]; then
                        log_debug "schema.xml and solrconfig.xml exists"
                        log "$ORIGIN will be used as confdir"
                        CONFDIR=$ORIGIN
                    else
                        log_error "${ORIGIN}/schema.xml and/or ${ORIGIN}/solrconfig.xml not exists"
                        exit 1
                    fi
                    break
                fi
            done
            if [ "x${CONFDIR}" == "x" ]; then
                log_error "no confdir defined. Place it in ${ORIGINS} or use --confdir param"
                exit 1
            fi
        fi
        # controllo se la conf esiste gia su zookeeper
        ${ZOOKEEPER_CONF} --action=check --confname=${CONFNAME}
        if [ $? -eq 0 ]; then
            # se esiste controllo se ci sono differenze fra la conf su zookeeper e la confdir specificata
            log "config ${CONFNAME} already exists, checking differencies"
            ${ZOOKEEPER_CONF} --action=checkconfigs --confname=${CONFNAME} --confdir=${CONFDIR}
            if [ $? -eq 0 ]; then
                log_debug "no differencies, continue without creating conf. Existing config will be used"
            else
                # se ci sono dele differenze propongo l'aggiornamento delle conf utilizzando la confdir specificata
                get_confirm "[*] ATTENTION! a conf named ${CONFNAME} already exists, do you want to update it with config files in ${CONFDIR}? Note: update will have impact on all collection that uses conf ${CONFNAME}[S/N] "
                ${ZOOKEEPER_CONF} --action=upconfig --confname=${CONFNAME} --confdir=${CONFDIR}
                if [ $? -eq 0 ]; then
                    log "config ${CONFDIR} successfully uploaded to zookeeper"
                else
                    log_error "error uploading ${CONFDIR} to zookeeper\n${ZOOKEEPER_CONF} --action=upconfig --confname=${CONFNAME} --confdir=${CONFDIR}"
                    exit 1
                fi
            fi
        else
            # se la conf non esiste la creo
            log_debug "config ${CONFNAME} not exists. Conf will be created"
            ${ZOOKEEPER_CONF} --action=upconfig --confname=${CONFNAME} --confdir=${CONFDIR}
            if [ $? -eq 0 ]; then
                log_debug "Conf ${CONFNAME} successfully uploaded to zookeeper using ${CONFDIR}"
            else
                log_error "error uploading ${CONFDIR} to zookeeper\n${ZOOKEEPER_CONF} --action=upconfig --confname=${CONFNAME} --confdir=${CONFDIR}"
                exit 1
            fi
        fi
        get_confirm "[*] Collection named ${COLLECTION_NAME} will be created using config ${CONFNAME}. Shards: ${SHARDS}, ReplicationFactor: ${REPLICA}. Do you confirm [S/N]?"
        log "creating collection ${COLLECTION_NAME} using conf ${CONFNAME}"
        $CURL "http://${SOLR_ADDRESS}/solr/admin/collections?action=CREATE&name=${COLLECTION_NAME}&numShards=${SHARDS}&replicationFactor=${REPLICA}&collection.configName=${CONFNAME}" -o $tmp_resp 2> /dev/null
    fi
fi

STATUS=`echo "cat //response/lst[@name='responseHeader']/int[@name='status']/text()" | xmllint --shell $tmp_resp | grep -v '/ >' | egrep -v '\-\-\-'`
if [ $STATUS -eq 0 ]; then
    log "Collection ${COLLECTION} successfully ${ACTION}"
    log_debug "`cat $tmp_resp`"
    exit 0
else
    error_string=`echo "cat //response/lst[@name='error']/str[@name='msg']/text()" | xmllint --shell $tmp_resp | grep -v '/ >' | egrep -v '\-\-\-'`
    log_error "$error_string"
    log_debug "`cat $tmp_resp`"
    exit 1
fi
