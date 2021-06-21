bind_addr = "0.0.0.0"
log_level = "INFO"

client {
  network_interface = "{{ GetDefaultInterfaces| attr \"name\" }}"
}

consul {
  address = "127.0.0.1:8500"
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}
