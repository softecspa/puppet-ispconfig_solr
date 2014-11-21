define ispconfig_solr::upstream_member (
  $upstream,
  $server,
  $port
) {

  nginx::resource::upstream::member{ $name:
    upstream  => $upstream,
    server    => $server,
    port      => $port
  }

}
