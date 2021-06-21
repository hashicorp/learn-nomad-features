job "monitoring" {
  datacenters = ["dc1"]

  group "metrics" {
    network {
      mode = "host"

      port "db" {
        static = 8086
      }
    }

    service {
      name = "influx"
      port = "db"
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
        data        = file("files/nomad_scraper.json.tmpl")
        destination = "../alloc/nomad_scraper.json.tmpl"
      }

      template {
        data        = file("files/influx_setup.sh")
        destination = "../alloc/docker-entrypoint-initdb.d/influx_setup.sh"
        perms       = 755
      }

      template {
        data        = file("files/influx_poststart.sh")
        destination = "../alloc/influx_poststart.sh"
        perms       = 755
      }

      template {
        data        = "{{ base64Decode \"${base64encode(file("files/influx.yaml"))}\" }}"
        destination = "../alloc/influx.yaml"
      }
    }

    task "poststart" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = "false"
      }

      config {
        image      = "curlimages/curl:7.77.0"
        entrypoint = ["/alloc/influx_poststart.sh"]
      }
    }

    task "influx" {
      driver = "docker"

      env {
        DOCKER_INFLUXDB_INIT_MODE = "setup"
        DOCKER_INFLUXDB_INIT_USERNAME = "admin"
        DOCKER_INFLUXDB_INIT_PASSWORD = "password"
        DOCKER_INFLUXDB_INIT_ORG = "Nomad"
        DOCKER_INFLUXDB_INIT_BUCKET = "nomad"
      }

      config {
        image = "influxdb:2.0.7"
        ports = ["db"]

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
  }
}
