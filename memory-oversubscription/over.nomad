job "over" {
  datacenters = ["dc1"]

  group "group" {
    task "task" {
      driver = "docker"

      config {
        force_pull = true
        image = "voiselle/wave:v2"
        args = [
         "--baseline","5000000",
         "--magnitude","2000000",
         "--period","50"
        ]
      }

      resources {
        cpu    = 500
        memory = 400
      }
    }
  }
}
