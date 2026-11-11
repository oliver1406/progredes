# Create the VM Volume
resource "libvirt_volume" "ubuntu-base-img" {
  name = "ubuntu-base-tf.img"
  pool = "default"
  source = "https://cloud-images.ubuntu.com/daily/server/jammy/current/jammy-server-cloudimg-amd64-disk-kvm.img"
  format = "qcow2"
}

resource "libvirt_volume" "master-img" {
  name = "master-tf.img"
  pool = "default"
  base_volume_id = "${libvirt_volume.ubuntu-base-img.id}"
  size = "10000000000"
  format = "qcow2"
}

resource "libvirt_volume" "worker01-img" {
  name = "worker01-tf.img"
  pool = "default"
  base_volume_id = "${libvirt_volume.ubuntu-base-img.id}"
  size = "10000000000"
  format = "qcow2"
}

resource "libvirt_volume" "worker02-img" {
  name = "worker02-tf.img"
  pool = "default"
  base_volume_id = "${libvirt_volume.ubuntu-base-img.id}"
  size = "10000000000"
  format = "qcow2"
}

# Create the Kubernetes Master Node
resource "libvirt_domain" "master" {
  name   = "master"
  memory = "2056"
  vcpu   = 2

  network_interface {
    network_name = "default"
  }

  disk {
    volume_id = "${libvirt_volume.master-img.id}"
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}

# Create the Kubernetes Worker Node
resource "libvirt_domain" "worker01" {
  name   = "worker01"
  memory = "2056"
  vcpu   = 2

  network_interface {
    network_name = "default"
  }

  disk {
    volume_id = "${libvirt_volume.worker01-img.id}"
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}

# Create the Kubernetes Worker Node
resource "libvirt_domain" "worker02" {
  name   = "worker02"
  memory = "2056"
  vcpu   = 2

  network_interface {
    network_name = "default"
  }

  disk {
    volume_id = "${libvirt_volume.worker02-img.id}"
  }

  cloudinit = "${libvirt_cloudinit_disk.commoninit.id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}