class ispconfig_solr::newrelic {

  if $newrelic_license_free_key == '' {
    fail ('please define global variables newrelic_license_free_key')
  }


  $newrelic_license_key = $newrelic_license_pro_key?{
    ''      => $newrelic_license_free_key,
    default => $newrelic_license_pro_key
  }

  if !defined (Newrelic::Server[$hostname]) {
    newrelic::server { $hostname:
      newrelic_license_key => $newrelic_license_key,
    }
  }

  #newrelic::java {
  #  "PHP Application on Cluster $cluster":
  #    newrelic_license_key      => $newrelic_license_key,
  #    newrelic_php_conf_appname => "PHP Application on Cluster $cluster",
  #}

}
