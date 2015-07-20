notice('MODULAR: detach-keystone/hiera-override.pp')

$detach_keystone_plugin = hiera('detach-keystone', undef)

if $detach_keystone_plugin {
  $network_metadata = hiera_hash('network_metadata')
  $settings_hash    = parseyaml($detach_keystone_plugin['yaml_additional_config'])
  $nodes_hash       = hiera('nodes')
  $management_vip   = hiera('management_vip')
  $keystone_vip     = hiera('service_endpoint')

  if hiera('role', 'none') == 'primary-keystone' {
    $primary_keystone = 'true'
  } else {
    $primary_keystone = 'false'
  }
  if hiera('role', 'none') =~ /^primary/ {
    $primary_controller = 'true'
  } else {
    $primary_controller = 'false'
  }

  $keystone_nodes      = get_nodes_hash_by_roles($network_metadata,
    ['primary_keystone', 'keystone'])
  $keystone_ipaddr_map = get_node_t_ipaddr_map_by_network_role($keystone_nodes,
    'mgmt/keystone')
  $keystone_ips        = values($keystone_ipaddr_map)
  $keystone_names      = keys($keystone_ipaddr_map)

  case hiera('role', 'none') {
    /keystone/: {
      $corosync_roles = ['primary-keystone', 'keystone']
      $deploy_vrouter = 'false'
      $corosync_nodes = $keystone_nodes
    }
    /controller/: {
      $deploy_vrouter = 'true'
      $mysql_enabled  = 'false'
    }
    default: {
      $corosync_roles = ['primary-controller', 'controller']
    }
  }

  $calculated_content = inline_template('
primary_keystone: <%= @primary_keystone %>
keystone_vip: <%= @keystone_vip %>
<% if @keystone_nodes_ips -%>
keystone_nodes:
<% @keystone_nodes_ips.each do |dbnode| %>  - <%= dbnode %><% end -%>
keystone_ipaddresses:
<% @keystone_nodes_ips.each do |dbnode| %>  - <%= dbnode %><% end -%>
<% end -%>
<% if @keystone_nodes_names -%>
keystone_names:
<% @keystone_nodes_names.each do |dbnode| %>  - <%= dbnode %><% end -%>
<% end -%>
primary_controller: <%= @primary_controller %>
<% if @corosync_nodes -%>
corosync_nodes:
<% @corosync_nodes.each do |cnode| %>  - <%= cnode %><% end -%>
<% end -%>
<% if @corosync_roles -%>
corosync_roles:
<% @corosync_roles.each do |crole| %>  - <%= crole %><% end -%>
<% end -%>
deploy_vrouter: <%= @deploy_vrouter %>
')

  file { '/etc/hiera/override':
    ensure  => directory,
  }

  file { '/etc/hiera/override/plugins.yaml':
    ensure  => file,
    content => "${detach_db_plugin['yaml_additional_config']}\n${calculated_content}\n",
    require => File['/etc/hiera/override']
  }

  package { 'ruby-deep-merge':
    ensure  => 'installed',
  }

  file_line { 'hiera.yaml':
    path => '/etc/hiera.yaml',
    line => ':merge_behavior: deeper',
  }

}
