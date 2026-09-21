output "vm_name" {
  value = "${var.student_name}-${var.vm_name}"
}

output "vnc_display" {
  value = "virsh vncdisplay ${var.student_name}-${var.vm_name}"
}

output "display_command" {
  value = "virsh domdisplay ${var.student_name}-${var.vm_name}"
}
