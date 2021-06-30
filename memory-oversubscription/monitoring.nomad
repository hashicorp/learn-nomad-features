locals {
  username = "admin"
  password = "password"
  org = "Nomad"
  bucket = "nomad"
  retention = "1h"
  admin_token = "static-predefined-token"
}

job "monitoring" {
  datacenters = ["dc1"]

  group "metrics" {
    network {
      mode = "host"

      port "influx" {
        static = 8086
      }
      port "statsd" {
        static = 8125
      }
      port "udp" {
        static = 8092
      }
      port "tcp" {
        static = 8094
      }
    }

    service {
      name = "influx"
      port = "influx"
    }

    task "prestart" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = "false"
      }

      config {
        image   = "alpine:3.14.0"
        command = "/bin/sh"
        args    = ["-c", "echo 'Creating directories'; mkdir -p /alloc/data /alloc/config /alloc/docker-entrypoint-initdb.d ; ls -al /alloc"]
      }

      template {
        data        = file("files/influx_setup.sh")
        destination = "../alloc/docker-entrypoint-initdb.d/influx_setup.sh"
        perms       = 755
      }

      template {
        data        = "{{ base64Decode \"${base64encode(file("files/influx.yaml"))}\" }}"
        destination = "../alloc/influx.yaml"
      }
    }

    task "influx" {
      driver = "docker"

      env  {
        DOCKER_INFLUXDB_INIT_MODE        = "setup"
        DOCKER_INFLUXDB_INIT_USERNAME    = local.username
        DOCKER_INFLUXDB_INIT_PASSWORD    = local.password
        DOCKER_INFLUXDB_INIT_ORG         = local.org
        DOCKER_INFLUXDB_INIT_BUCKET      = local.bucket
        DOCKER_INFLUXDB_INIT_RETENTION   = local.retention
        DOCKER_INFLUXDB_INIT_ADMIN_TOKEN = local.admin_token
      }

      config {
        image = "influxdb:2.0.7"
        ports = ["influx"]

        mount {
          type   = "bind"
          source = "../alloc/data"
          target = "/var/lib/influxdb2"
        }

        mount {
          type   = "bind"
          source = "../alloc/docker-entrypoint-initdb.d"
          target = "/docker-entrypoint-initdb.d"
        }

        mount {
          type   = "bind"
          source = "../alloc/config"
          target = "/etc/influxdb2"
        }
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }

    task "telegraf" {
      lifecycle {
        hook    = "poststart"
        sidecar = "true"
      }

      env  {
        INFLUX_ORG    = local.org
        INFLUX_BUCKET = local.bucket
        INFLUX_TOKEN  = local.admin_token
      }

      driver = "docker"
      config {
        image = "telegraf:1.19"
        ports = ["statsd","udp","tcp"]

        mount {
          type     = "bind"
          source   = "local/telegraf.conf"
          target   = "/etc/telegraf/telegraf.conf"
          readonly = true
        }
      }

      template {
        data        = file("files/telegraf.conf")
        destination = "local/telegraf.conf"
      }
    }
  }
}
