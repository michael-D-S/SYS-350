# main.tf - Your first Terraform configuration

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

#Shared server: your student identifier prefixes all resource names
variable "student_name" {
  type        = string
  description = "Your student identifier (e.g., jsmith, mgarcia)"

  validation {
    condition     = can(regex("^[a-z]{2,10}$", var.student_name))
    error_message = "Student name must be 2-10 lowercase letters."
  }
}

variable "host_port" {
  description = "Port on the host (coordinate with your partner)"
  type        = number
  default     = 8080
}

# Pull the nginx image (equivalent to: docker pull nginx:latest)
resource "docker_image" "nginx" {
  name = "nginx:latest"
}

# Create a custom Docker network (like a libvirt virtual network)
resource "docker_network" "lan" {
  name = "${var.student_name}-sys350-lan"
}

# Create a named volume for persistent data
resource "docker_volume" "web_data" {
  name = "${var.student_name}-nginx-html"
}

# Create a container (equivalent to: docker run -d --name web-server -p 8080:80 nginx)
resource "docker_container" "web_server" {
  name  = "${var.student_name}-web-server"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.host_port
  }

  networks_advanced {
    name = docker_network.lan.name
  }

  volumes {
    volume_name    = docker_volume.web_data.name
    container_path = "/usr/share/nginx/html"
    read_only      = false
  }
}

output "container_ip" {
  value = docker_container.web_server.network_data[0].ip_address
}
