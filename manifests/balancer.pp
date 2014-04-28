define ispconfig_solr::balancer (
  $balancer         = 'nginx',
  $listen_address   = '',
  $listen_interface = '',
  $cluster          = '',
  $port             = '8980'
) {

  if ($balancer != 'nginx') and ($balancer != 'haproxy') {
    fail('supported balancer are nginx and haproxy')
  }

  if ($listen_address == '') and ($listen_interface == '') {
    fail('specify listen_address or listen_interface')
  }

  $listen_ip = $listen_address?{
    ''      => inline_template("<%= ipaddress_${listen_interface} %>"),
    default => $listen_address
  }

  case $balancer {
    'nginx': {
      nginx::resource::vhost { "solr_${cluster}":
        ensure      => present,
        listen_ip   => $listen_ip,
        listen_port => $port,
        server_name => "solr_${cluster}.${backplane_domain}",
        www_root    => '/var/www',
      }

      nginx::resource::location { "solr_${cluster}":
        vhost             => "solr_${cluster}",
        location          => '/solr',
        proxy             => "http://solr_${cluster}",
        proxy_set_header  => ['X-Forwarded-Host $host', 'X-Forwarded-Server $host', 'X-Forwarded-For $proxy_add_x_forwarded_for'],
        lines             => ['auth_basic "Restricted Solr admin";',
                              'auth_basic_user_file  /opt/solr/.htpasswd;'],
      }

      nginx::resource::upstream {"solr_${cluster}":}
      Nginx::Resource::Upstream_member <<| upstream == "solr_${cluster}" |>>
    }
  }

}
