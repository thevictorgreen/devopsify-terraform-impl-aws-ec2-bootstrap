# NNNNN variables
variable "NNNNN_machine_names" {
  description = "Host names for NNNNN machines"
  type = list(string)
  default = ["NNNNN000"]
}

variable "NNNNN_machine_subnets" {
  description = "Subnet where each host is to be provisioned"
  type = "map"
  default = {
    "NNNNN000" = "PLACE-SUBNETS-HERE"
  }
}

# THIS SECTION IS OPTIONAL
variable "NNNNN_machine_ips" {
  description = "Static Private IP Address for each host. Must be valid for subnet"
  type = "map"
  default = {
    "NNNNN000" = "XXX.XXX.XXX.XXX"
  }
}

# THIS SECTION ONLY REQUIRED IF ADDING EXTERNAL STORAGE
variable "NNNNN_machine_azs" {
  description = "availability_zones for each host"
  type = map(string)
  default = {
    "NNNNN0000" = "us-east-1a"
  }
}

variable "NNNNN_machine_ansible_group" {
  default = "NNNNN"
}

# NNNNN MACHINE
resource "aws_instance" "NNNNN-machine" {
  for_each      = "${toset(var.NNNNN_machine_names)}"
  ami           = "${var.amis["ubuntu_18_04"]}"
  instance_type = "${var.instance_type["medium"]}"

  key_name      = "${var.keypairs["KEYPAIR-HERE"]}"
  subnet_id     = "${var.subnets[ var.NNNNN_machine_subnets[ each.value ] ]}"

  # COMMENT THIS SECTION FOR AUTO-ASSIGNED IP ADDRESS
  private_ip    = "${var.NNNNN_machine_ips[ each.value ]}"

  vpc_security_group_ids = [
    "${var.secgroups["SECURITY-GROUP-HERE"]}"
  ]

  root_block_device {
    volume_type = "standard"
    volume_size = 80
  }
  connection {
    private_key = "${file(var.private_key)}"
    user        = "${var.ansible_user["ubuntu_18_04"]}"
    host        = "${self.private_ip}"
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
    AnsibleRole = "NNNNN"
    ClusterRole = "none"
  }
}


resource "aws_route53_record" "NNNNN-machine-private-record" {
  for_each = "${toset(var.NNNNN_machine_names)}"
  zone_id  = "${data.aws_route53_zone.dns_private_zone.zone_id}"
  name     = "${each.value}.${data.aws_route53_zone.dns_private_zone.name}"
  type     = "A"
  ttl      = "300"

  # SWAP THESE TWO SECTIONS IF USING AUTO-ASSIGNED IP ADDRESSES
  #records  = ["${aws_instance.NNNNN-machine[each.value].private_ip}"]
  records = ["${var.NNNNN_machine_ips[ each.value ]}"]
}


resource "aws_route53_record" "NNNNN-machine-reverse-record" {
  for_each = "${toset(var.NNNNN_machine_names)}"
  zone_id = "${data.aws_route53_zone.dns_reverse_zone.zone_id}"

  # SWAP THESE TWO SECTIONS IF USING AUTO-ASSIGNED IP ADDRESSES
  #name    = "${element(split(".", aws_instance.NNNNN-machine[each.value].private_ip),3)}.${element(split(".", aws_instance.NNNNN-machine[each.value].private_ip),2)}.${data.aws_route53_zone.dns_reverse_zone.name}"
  name    = "${element(split(".", var.NNNNN_machine_ips[ each.value ]),3)}.${element(split(".", var.NNNNN_machine_ips[ each.value ]),2)}.${data.aws_route53_zone.dns_reverse_zone.name}"
  records = ["${each.value}.${data.aws_route53_zone.dns_private_zone.name}"]
  type    = "PTR"
  ttl     = "300"
}

/* UNCOMMENT THIS SECTION TO ADD ADDITIONAL HARD DRIVES TO INSTANCE
resource "aws_ebs_volume" "NNNNN-volume1" {
  for_each = "${toset(var.NNNNN_machine_names)}"
  availability_zone = "${var.NNNNN_machine_azs[ each.value ]}"
  type = "gp2"
  size = 200
}

resource "aws_volume_attachment" "NNNNN-volume1-attachment" {
  for_each    = "${toset(var.NNNNN_machine_names)}"
  device_name = "/dev/xvdb"
  instance_id = "${aws_instance.NNNNN-machine[ each.value ].id}"
  volume_id   = "${aws_ebs_volume.NNNNN-volume1[ each.value ].id}"
}*/

/* UNCOMMENT THIS SECTION TO EXPOSE THIS INSTANCE PUBLICLY
resource "aws_eip" "NNNNN-machine-eip" {
  for_each = "${toset(var.NNNNN_machine_names)}"
  instance = "${aws_instance.NNNNN-machine[each.value].id}"
  vpc      = true
}


resource "aws_route53_record" "NNNNN-machine-public-record" {
  for_each = "${toset(var.NNNNN_machine_names)}"
  zone_id  = "${data.aws_route53_zone.dns_public_zone.zone_id}"
  name     = "${each.value}.AAAAA.${data.aws_route53_zone.dns_public_zone.name}"
  type     = "A"
  ttl      = "300"
  records  = ["${aws_eip.NNNNN-machine-eip[each.value].public_ip}"]
}
*/
