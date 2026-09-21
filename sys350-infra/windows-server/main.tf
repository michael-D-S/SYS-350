terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Thin overlay on the shared base image (no 40G copy)
resource "terraform_data" "disk" {
  input = {
    name  = "${var.student_name}-${var.vm_name}"
    image = var.image_path
  }

  provisioner "local-exec" {
    command = "sudo qemu-img create -f qcow2 -F qcow2 -b ${var.image_path} /var/lib/libvirt/images/${var.student_name}-${var.vm_name}.qcow2 && sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/${var.student_name}-${var.vm_name}.qcow2"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sudo rm -f /var/lib/libvirt/images/${self.input.name}.qcow2"
  }
}

# My own NAT network (default doesn't exist on this host)
resource "libvirt_network" "lab_net" {
  name      = "${var.student_name}-lan"
  autostart = true

  forward = {
    mode = "nat"
  }

  ips = [
    {
      address = "192.168.101.1"
      family  = "ipv4"
      prefix  = 24
      dhcp = {
        ranges = [
          {
            start = "192.168.101.100"
            end   = "192.168.101.254"
          }
        ]
      }
    }
  ]
}

resource "libvirt_domain" "windows_server" {
  name        = "${var.student_name}-${var.vm_name}"
  memory      = var.ram_size
  memory_unit = "KiB"
  vcpu        = var.cpu_cores
  type        = "kvm"
  autostart   = true
  running     = true

  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }

  features = {
    acpi = true
    apic = {}
  }

  devices = {
    disks = [
      {
        source = {
          file = {
            file = "/var/lib/libvirt/images/${var.student_name}-${var.vm_name}.qcow2"
          }
        }
        driver = {
          type = "qcow2"
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

    interfaces = [
      {
        source = {
          network = {
            network = libvirt_network.lab_net.name
          }
        }
        model = {
          type = "e1000e"
        }
      }
    ]

    graphics = [
      {
        spice = {
          auto_port = true
          listen    = "0.0.0.0"
        }
      }
    ]

    serials = [
      {
        type = "pty"
      }
    ]

    consoles = [
      {
        type = "pty"
        target = {
          type = "serial"
          port = 0
        }
      }
    ]
  }

  depends_on = [
    terraform_data.disk
  ]
}
