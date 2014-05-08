# == Define: ispconfig_solr::newrelic
#
# This define is a wrapper of newrelic::java class. It install newrelic java agent
#
# == Parameters:
#
# [*path*]
#   Path where agent will be installed
#
# == Global Variables
# Global variable newrelic_license_free_key will be used as newrelic license key.
# It can be overriden by defining newrelic_license_pro_key variable (ex: at cluster level or where solr instance is defined)
#
# === Sample Usage of free license
#
# node foo {
#   newrelic::java {'appXYZ':
#     path  => "/opt/newrelic",
#   }
# }
#
# === Sample Usage of pro license
#
# node foo {
#   $newrelic_license_pro_key = 'YYYYYYYYYYYYY'
#   newrelic::java {'appXYZ':
#     path => "/opt/newrelic",
#   }
# }
#
define ispconfig_solr::newrelic (
  $path,
) {

  if $newrelic_license_free_key == '' {
    fail ('please define global variables newrelic_license_free_key')
  }


  if !defined (Newrelic::Server[$hostname]) {
    newrelic::server { $hostname: }
  }

  if !defined(Class['newrelic::java']) {
    class{'newrelic::java':
      path                        => "$path/newrelic",
      newrelic_java_conf_appname  => "Java Apps on $cluster",
    }
  }

}
