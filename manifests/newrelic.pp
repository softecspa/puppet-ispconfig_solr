define ispconfig_solr::newrelic (
  $path,
) {

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

  if !defined(Class['newrelic::java']) {
    class{'newrelic::java':
      path                        => "$path/newrelic",
      newrelic_license_key        => $newrelic_license_key,
      newrelic_java_conf_appname  => "Java Apps on $cluster",
    }
  }

}
