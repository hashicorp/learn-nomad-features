# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

job "wave" {
  datacenters = ["dc1"]

  group "wave" {
    task "wave" {
      driver = "docker"

      config {
        force_pull = true
        image = "voiselle/wave:v5"
        args = [ "300", "200", "15", "64", "4" ]
      }

      resources {
        cpu    = 500
        memory = 520
      }
    }
  }
}
