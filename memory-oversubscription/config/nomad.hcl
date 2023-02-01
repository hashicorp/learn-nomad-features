# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

bind_addr = "0.0.0.0"
log_level = "INFO"
name      = "nomad-tutorial-server"

client {
  network_interface = "{{ GetDefaultInterfaces| attr \"name\" }}"
}

consul {
  # This configuration is intentionally bogus to prevent this Nomad instance
  # from finding a local consul agent and inadvertantly joining a cluster.
  # The other settings are self-defense on the off-chance that there happens to
  # be a consul agent on that extremely contrived junk address.
  address             = "127.0.0.222:8500"
  server_service_name = "nomad-dev-server"
  client_service_name = "nomad-dev-client"
  auto_advertise      = false
  server_auto_join    = false
  client_auto_join    = false
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}
