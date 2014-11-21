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
  $java_version,
  $newrelic_license_key = hiera('newrelic_license_key'),
  $cluster              = $cluster,
) {

  if $newrelic_license_free_key == '' {
    fail ('please define global variables newrelic_license_free_key')
  }

  include softec_newrelic::server

  $newrelic_java_version = regsubst($java_version,'[^(0-9)]','','G')

  if !defined(Class['softec_newrelic::java']) {
    class{'softec_newrelic::java':
      newrelic_java_plugin_path => $path,
      newrelic_java_appname     => "Java Apps on ${cluster}",
      java_version              => $newrelic_java_version
    }
  }

}
