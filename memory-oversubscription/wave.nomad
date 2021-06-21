job "wave" {
  datacenters = ["dc1"]

  group "wave" {
    task "wave" {
      driver = "docker"

      config {
        force_pull = true
        image = "voiselle/wave:v4"
        args = [
         "300",
         "200",
         "15",
         "32",
         "4"
        ]
      }

      resources {
        cpu    = 500
        memory = 520
      }
    }
  }
}
