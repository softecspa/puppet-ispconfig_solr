# == Define: ispconfig_solr::instance
#
# This define is a wrapper of solr::instance. It creates a solr instance and configure it for use in IspConfig environment
#
# == Parameters:
#
# [*instance_name*]
#  name of solr instance. Instance will be called solr-$instance_name. If not present <name> will be used
#
# [*app_server*]
#  Application server to use for deploy solr webapp. Actually only jetty is supported. Default: jetty
#
# [*jetty_version*]
#  If app_server is jetty, this parameter indicate which version of jetty must be used
#
# [*jetty_s3_bucket*]
#  If app_server is jetty, this parameter indicate the name of s3 where jetty install is stored
#
# [*jetty_download_url*]
#  If app_server is jetty, this parameter indicate the url where jetty can be downloaded
#
# [*jetty_root*]
#  If app_server is jetty, this parameter indicate the root path where jetty will be installed. Default: /opt
#
# [*jetty_user*]
#  If app_server is jetty, this parameter indicate user for jetty process. Default: jetty
#
# [*jetty_uid*]
#  If app_server is jetty, this parameter indicate uid for jetty user. Default: unset
#
# [*jetty_gid*]
#  If app_server is jetty, this parameter indicate gid for jetty user. Default: unset
#
# [*listen_address*]
#  IP address on which solr instance is listening
#
# [*listen_interface*]
#  Interface used by solr to listen to. ipaddress_${listen_interface} will be used as listen_address
#
# [*port*]
#  Port on which solr instance will listen. Mandatory
#
# [*solr_version*]
#  Solr version to install. Mandatory
#
# [*solr_root*]
#  Root path where solr will be installed. Default: /opt
#
# [*cloud*]
#  If true, solr will be configured with zookeeper utilization for a SolrCloud installation. Zookeeper nodes have to be defined first or defined used zookeeper_servers
#  parameter (See example). Default: true
#
# [*zookeeper_servers*]
#  String that can be used, in a SolrCloud installation, to specify zookeeper ensemble's nodes. String must be in form $zoohost1:$port1,$zoohost2:$port2,$zoohost3:$port3
#  eventually followed by /$cluster if zookeeper ensemble is chrooted (ex: a zookeeper ensembled used by more clusters). If not specified a query to the puppetdb will be done
#  to retrieve zookeeper's nodes
#
# [*balanced*]
#  If true, instance will be balanced. All solr instances on the same cluster (identified by cluster variable) will be balanced twice: on a public (and protected) address, and
#  on a private address used by application. Default: true
#
# [*private_balancer*]
#  If balanced=true, private balancement will be done through this balancer. Accepted value: apache2, nginx, haproxy but actually only apache2 is supported. Default: apache2
#   - if apache2: this define exports apache2 fragment to balance the instance. Nodes having the same $cluster variable value and the class ispconfig-cluster applied on it
#     and the variable "$enable_solr = true" will collect this fragment to do the balancement service.
#
# [*public_balancer*]
#  If balanced=true, public balancement will be done through this balancer. Accepted value: apache2, nginx, haproxy but actually only nginx is supported. Default: nginx
#   - if nginx: this define exports this instances as an nginx upstream member
#
# [*cluster*]
#  Used to override $cluster variable defined at cluster level. Default: $cluster
#
# [*newrelic*]
#  If true, newrelic java agent will be installed through softec_newrelic::java define. Default: true
#
# [*monitored*]
#  It true, instance will ben monitored by nagios
#
# [*monitored_hostname*]
#  Hostname used by nagios to perform the checks. Default: $::hostname
#
# [*notifications_enabled*]
#  1 enable nagios notification, 0 otherwise. Default: undef
#
# [*notification_period*]
#  Notification period used in nagios service. Default: undef
#
# == Sample Usage:
#  In a SolrCloud installation, ispconfig_solr and zookeeper module are used in conjuction.
#  Suppose to have a cluster named ZOO where a zookeeper ensemble will be installed, and a cluster named SOLRCLUSTER where we want to install a SolrCloud system.
#  First, we define the zookeeper ensemble's nodes in the cluster ZOO definition (suppose three instances on the same machine).
#  After this, we define ispconfig_solr::instance, the define will call the puppetDB to know the zookeeper's nodes.
#
# ZOOKEEPER SECTION
# node ZOO {
#   $cluster = 'zoo'
#
#   class {'zookeeper::ensemble::solr':
#     chroot  => true,
#     nodes   => {'zoohost:port1' => {id =>1, address => 'zoohost', client_port => 'port1', leader_port =>'l_port1', election_port => 'e_port1'},
#                 'zoohost:port2' => {id =>2, address => 'zoohost', client_port => 'port2', leader_port =>'l_port2', election_port => 'e_port2'},
#                 'zoohost:port3' => {id =>3, address => 'zoohost', client_port => 'port3', leader_port =>'l_port3', election_port => 'e_port3'}},
#     tags    => ['SOLRCLUSTER']
#   }
# }
# NOTE: see zookeeper::ensemble::solr documentation for more information about used variables
#
# node zoohost inherits ZOO {
#   Zookeeper::Instance {
#     listen_address  => 'x.x.x.x',
#   }
#   zookeeper::instance {'1':}
#   zookeeper::instance {'2':}
#   zookeeper::instance {'3':}
# }
# SOLR SECTION
#
# node SOLRCLUSTER {
#
#   $cluster = 'SOLRCLUSTER'
#
#   Ispconfig_solr::Instance {
#     jetty_version     => '9.1.3',
#     jetty_s3_bucket   => 'softec-jetty',
#     solr_version      => '4.7.0',
#   }
# }
#
# node solr1 inherits SOLRCLUSTER {
#   ispconfig_solr::instance {'solr1':
#     listen_address => 'x.x.x.x'
#     port  => '8983',
#   }
# }
#
# node solr2 inherits SOLRCLUSTER {
#   ispconfig_solr::instance {'solr2':
#     listen_address => 'x.x.x.x'
#     port  => '8984',
#   }
# }
# ISPCONFIG FE SECTION
# node frontend01 inherits SOLRCLUSTER {
#   enable_solr = true
#   include ispconfig_cluster_slave
# }
#
define ispconfig_solr::instance (
  $instance_name          = '',
  $app_server             = 'jetty',
  $jetty_version          = '',
  $jetty_s3_bucket        =  '',
  $jetty_download_url     = '',
  $jetty_root             = '/opt',
  $jetty_user             = 'jetty',
  $jetty_uid              = undef,
  $jetty_gid              = undef,
  $listen_address         = '',
  $listen_interface       = '',
  $port,
  $solr_version,
  $solr_root              = '/opt',
  $cloud                  = true,
  $zookeeper_servers      = '',
  $balanced               = true,
  $private_balancer       = 'apache2',
  $public_balancer        = 'nginx',
  $cluster                = $cluster,
  $newrelic               = true,
  $monitored              = true,
  $monitored_hostname     = $::hostname,
  $notifications_enabled  = undef,
  $notification_period    = undef,
) {

  $listen = $listen_address?{
    ''      => inline_template("<%= ipaddress_${listen_interface} %>"),
    default => $listen_address
  }

  $java_options = $newrelic?{
    true  => "-javaagent:${solr_root}/newrelic/newrelic.jar",
    false => '',
  }

  $in = $instance_name? {
    ''      => $name,
    default => $instance_name
  }

  if $newrelic {
    $jetty_deploy_parameters = {"newrelic-appname-${in}" => {param_name => 'com.newrelic.agent.APPLICATION_NAME', param_value => "solr-${in}"},}
  }
  else {
    $jetty_deploy_parameters = ''
  }

  solr::instance {$name:
    instance_name           => $instance_name,
    app_server              => $app_server,
    jetty_version           => $jetty_version,
    jetty_s3_bucket         => $jetty_s3_bucket,
    jetty_download_url      => $jetty_download_url,
    jetty_root              => $jetty_root,
    jetty_user              => $jetty_user,
    jetty_uid               => $jetty_uid,
    jetty_gid               => $jetty_gid,
    jetty_deploy_parameters => $jetty_deploy_parameters,
    listen_address          => $listen_address,
    listen_interface        => $listen_interface,
    port                    => $port,
    java_options            => $java_options,
    solr_version            => $solr_version,
    solr_root               => $solr_root,
    cloud                   => $cloud,
    zookeeper_servers       => $zookeeper_servers,
    monitored               => $monitored,
    monitored_hostname      => $monitored_hostname,
    notifications_enabled   => $notifications_enabled,
    notification_period     => $notification_period
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
        @@apache::balancermember { "${listen}:${port}":
          balancer_cluster  => "solr-${cluster}",
          url               => "http://${listen}:${port}",
          tag               => "solr-${cluster}"
        }
      }
    }

    case $public_balancer {
      'haproxy': {
        fail ('public_balancer through haproxy is not implemented yet')
      }

      'nginx': {
        @@ispconfig_solr::nginx::upstream_member{ "${listen}:${port}":
          upstream  => "solr-${cluster}",
          server    => $listen,
          port      => $port
        }
      }

      'apache2': {
        fail ('public_balancer through apache is not implemented yet')
      }
    }
  }
  if $newrelic {
    ispconfig_solr::newrelic {$name:
      path          => "${solr_root}/newrelic",
      java_version  => 'openjdk-7-jre'
    }
  }
}
