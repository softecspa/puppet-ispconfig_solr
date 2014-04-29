define ispconfig_solr::instance (
  $instance_name        = '',
  $app_server           = 'jetty',
  $jetty_version        = '',
  $jetty_s3_bucket      = '',
  $jetty_download_url   = '',
  $jetty_root           = '/opt',
  $jetty_user           = 'jetty',
  $jetty_uid            = undef,
  $jetty_gid            = undef,
  $listen_address       = '',
  $listen_interface     = '',
  $port,
  $solr_version,
  $solr_root            = '/opt',
  $cloud                = true,
  $zookeeper_servers    = '',
  $balanced             = true,
  $private_balancer     = 'apache2',
  $public_balancer      = 'nginx',
  $cluster              = $cluster,
  $newrelic             = true,
) {

  $listen = $listen_address?{
    ''      => inline_template("<%= ipaddress_${listen_interface} %>"),
    default => $listen_address
  }

  $java_options = $newrelic?{
    true  => "-javaagent:${solr_root}/newrelic/newrelic.jar",
    false => '',
  }

  solr::instance {$name:
    instance_name       => $instance_name,
    app_server          => $app_server,
    jetty_version       => $jetty_version,
    jetty_s3_bucket     => $jetty_s3_bucket,
    jetty_download_url  => $jetty_download_url,
    jetty_root          => $jetty_root,
    jetty_user          => $jetty_user,
    jetty_uid           => $jetty_uid,
    jetty_gid           => $jetty_gid,
    listen_address      => $listen_address,
    listen_interface    => $listen_interface,
    port                => $port,
    java_options        => $java_options,
    solr_version        => $solr_version,
    solr_root           => $solr_root,
    cloud               => $cloud,
    zookeeper_servers   => $zookeeper_servers,
  }

  if $balanced {
    if ($private_balancer != 'nginx') and ($private_balancer != 'haproxy') and ($private_balancer != 'apache2') {
      fail ('private_balancer support only nginx, haproxy and apache2')
    }

    if ($public_balancer != 'nginx') and ($public_balancer != 'haproxy') and ($public_balancer != 'apache2') {
      fail ('public_balancer support only nginx, haproxy and apache2')
    }



    case $private_balancer {

      'haproxy': {
        fail ('private_balancer through haproxy is not implemented yet')
      }

      'nginx': {
        fail ('private_balancer through nginx is not implemented yet')
      }

      'apache2': {
        @@concat_fragment{"solr-balancement+002-${listen}-${port}.tmp":
          content => "BalancerMember http://${listen}:${port}",
          tag     => "solr-${cluster}"
        }
      }
    }

    case $public_balancer {
      'haproxy': {
        fail ('public_balancer through haproxy is not implemented yet')
      }

      'nginx': {
        @@nginx::resource::upstream_member { "${listen}:${port}":
          upstream  => "solr-${cluster}",
        }
      }

      'apache2': {
        fail ('public_balancer through apache is not implemented yet')
      }
    }
  }
  if $newrelic {
    ispconfig_solr::newrelic {$name:
      path => $solr_root,
    }
  }
}
