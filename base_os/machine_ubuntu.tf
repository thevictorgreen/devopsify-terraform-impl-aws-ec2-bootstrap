# ubuntu variables
variable "ubuntu_machine_names" {
  description = "Host names for ubuntu machines"
  type = list(string)
  default = ["ubuntu000"]
}


variable "ubuntu_machine_subnets" {
  description = "Subnet where each host is to be provisioned"
  type = map(string)
  default = {
    "ubuntu000" = "AAAAA-useast1-public-us-east-1a-sn"
  }
}


variable "ubuntu_machine_azs" {
  description = "availability_zones for each host"
  type = map(string)
  default = {
    "ubuntu000" = "us-east-1a"
  }
}


variable "ubuntu_machine_ansible_group" {
  default = "ubuntu"
}


# ubuntu MACHINE
resource "aws_instance" "ubuntu-machine" {
  for_each      = toset(var.ubuntu_machine_names)
  ami           = var.amis["ubuntu_18_04"]
  instance_type = var.instance_type["medium"]

  key_name      = var.keypairs["QQQQQ"]
  subnet_id     = var.subnets[ var.ubuntu_machine_subnets[ each.value ] ]

  vpc_security_group_ids = [
    var.secgroups["AAAAA-useast1-public-security-group"]
  ]

  root_block_device {
    volume_type = "standard"
    volume_size = 80
  }
  connection {
    private_key = file(var.private_key)
    user        = var.ansible_user["ubuntu_18_04"]
    host        = self.public_ip
  }

  provisioner "file" {
    source = "scripts/AAAAA_prompt.sh"
    destination = "/tmp/custom_prompt.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${each.value}.AAAAA.${var.domain}",
      "sudo mv /tmp/custom_prompt.sh /etc/profile.d/custom_prompt.sh",
      "sudo chmod +x /etc/profile.d/custom_prompt.sh"
    ]
  }

  tags = {
    Name = "${each.value}"
    region = "us-east-1"
    env = "AAAAA"
    AnsibleRole = "ubuntu"
    ClusterRole = "none"
  }
}


resource "aws_route53_record" "ubuntu-machine-private-record" {
  for_each = toset(var.ubuntu_machine_names)
  zone_id  = data.aws_route53_zone.dns_private_zone.zone_id
  name     = "${each.value}.${data.aws_route53_zone.dns_private_zone.name}"
  type     = "A"
  ttl      = "300"

  records  = ["${aws_instance.ubuntu-machine[each.value].private_ip}"]
}


resource "aws_route53_record" "ubuntu-machine-reverse-record" {
  for_each = toset(var.ubuntu_machine_names)
  zone_id = data.aws_route53_zone.dns_reverse_zone.zone_id

  name    = "${element(split(".", aws_instance.ubuntu-machine[each.value].private_ip),3)}.${element(split(".", aws_instance.ubuntu-machine[each.value].private_ip),2)}.${data.aws_route53_zone.dns_reverse_zone.name}"
  records = ["${each.value}.${data.aws_route53_zone.dns_private_zone.name}"]
  type    = "PTR"
  ttl     = "300"
}


resource "aws_ebs_volume" "ubuntu-volume1" {
  for_each = toset(var.ubuntu_machine_names)
  availability_zone = var.ubuntu_machine_azs[ each.value ]
  type = "gp2"
  size = 80
}


resource "aws_volume_attachment" "ubuntu-volume1-attachment" {
  for_each    = toset(var.ubuntu_machine_names)
  device_name = "/dev/xvdb"
  instance_id = aws_instance.ubuntu-machine[ each.value ].id
  volume_id   = aws_ebs_volume.ubuntu-volume1[ each.value ].id
}


resource "aws_eip" "ubuntu-machine-eip" {
  for_each = toset(var.ubuntu_machine_names)
  instance = aws_instance.ubuntu-machine[each.value].id
  vpc      = true
}


resource "aws_route53_record" "ubuntu-machine-public-record" {
  for_each = toset(var.ubuntu_machine_names)
  zone_id  = data.aws_route53_zone.dns_public_zone.zone_id
  name     = "${each.value}.AAAAA.${data.aws_route53_zone.dns_public_zone.name}"
  type     = "A"
  ttl      = "300"
  records  = ["${aws_eip.ubuntu-machine-eip[each.value].public_ip}"]
}
