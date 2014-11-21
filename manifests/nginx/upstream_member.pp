define ispconfig_solr::nginx::upstream_member (
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
