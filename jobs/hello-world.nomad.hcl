job "hello-world" {
  datacenters = ["dc1"]
  type = "service"

  group "web" {
    count = 1

    network {
      mode = "host"
      port "http" { static = 8080 }
    }

    task "echo" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo:0.2.3"
        args  = ["-text=Hello from Nomad on GCP!"]
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }

      service {
        name = "hello-world"
        port = "http"
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
