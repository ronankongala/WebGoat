terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "webgoat" {
  name = "webgoat/webgoat:latest"
}

resource "docker_container" "webgoat" {
  name  = "webgoat"
  image = docker_image.webgoat.image_id

  ports {
    internal = 8080
    external = 8080
  }
  ports {
    internal = 9090
    external = 9090
  }

  restart = "on-failure"
}