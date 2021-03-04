# k8sworker variables
variable "k8sworker_machine_names" {
  description = "Host names for k8sworker machines"
  type = list(string)
  default = ["k8sworker000","k8sworker001","k8sworker002"]
}

variable "k8sworker_machine_subnets" {
  description = "Subnet where each host is to be provisioned"
  type = "map"
  default = {
    "k8sworker000" = "AAAAA-useast1-private-us-east-1a-sn"
    "k8sworker001" = "AAAAA-useast1-private-us-east-1a-sn"
    "k8sworker002" = "AAAAA-useast1-private-us-east-1a-sn"
  }
}

variable "k8sworker_machine_ips" {
  description = "Static Private IP Address for each host"
  type = "map"
  default = {
    "k8sworker000" = "IP-ADDR-HERE"
    "k8sworker001" = "IP-ADDR-HERE"
    "k8sworker002" = "IP-ADDR-HERE"
  }
}

variable "k8sworker_machine_azs" {
  description = "Availability zones for each host"
  type = "map"
  default = {
    "k8sworker000" = "us-east-1a"
    "k8sworker001" = "us-east-1a"
    "k8sworker002" = "us-east-1a"
  }
}

variable "k8sworker_machine_ansible_group" {
  default = "k8sworker"
}

# k8sworker MACHINE
resource "aws_instance" "k8sworker-machine" {
  for_each      = "${toset(var.k8sworker_machine_names)}"
  ami           = "${var.amis["kubernetes_ha_1_20_2_5"]}"
  instance_type = "${var.instance_type["large"]}"
  iam_instance_profile = "IAM-ROLE-HERE"

  key_name      = "${var.keypairs["kp_1"]}"
  subnet_id     = "${var.subnets[ var.k8sworker_machine_subnets[ each.value ] ]}"

  private_ip    = "${var.k8sworker_machine_ips[ each.value ]}"
  source_dest_check = false

  vpc_security_group_ids = [
    "${var.secgroups["AAAAA-useast1-cluster-security-group"]}"
  ]

  root_block_device {
    volume_type = "standard"
    volume_size = 80
  }

  connection {
    private_key = "${file(var.private_key)}"
    user        = "${var.ansible_user["centos_7"]}"
    host        = "${self.private_ip}"
  }

  provisioner "file" {
    source = "scripts/AAAAA_prompt.sh"
    destination = "/tmp/custom_prompt.sh"
  }

  user_data = <<-EOF
     #!/bin/bash
     sudo hostnamectl set-hostname "${each.value}.AAAAA.${var.domain}"
     sudo mv /tmp/custom_prompt.sh /etc/profile.d/custom_prompt.sh
     sudo chmod +x /etc/profile.d/custom_prompt.sh
  EOF

  tags = {
    Name = "${each.value}"
    region = "us-east-1"
    env = "AAAAA"
    AnsibleRole = "k8sworker"
    ClusterRole = "none"
  }
}


resource "aws_route53_record" "k8sworker-machine-private-record" {
  for_each = "${toset(var.k8sworker_machine_names)}"
  zone_id  = "${data.aws_route53_zone.dns_private_zone.zone_id}"
  name     = "${each.value}.${data.aws_route53_zone.dns_private_zone.name}"
  type     = "A"
  ttl      = "300"
  records = ["${var.k8sworker_machine_ips[ each.value ]}"]
}


resource "aws_route53_record" "k8sworker-machine-reverse-record" {
  for_each = "${toset(var.k8sworker_machine_names)}"
  zone_id = "${data.aws_route53_zone.dns_reverse_zone.zone_id}"
  name    = "${element(split(".", var.k8sworker_machine_ips[ each.value ]),3)}.${element(split(".", var.k8sworker_machine_ips[ each.value ]),2)}.${data.aws_route53_zone.dns_reverse_zone.name}"
  records = ["${each.value}.${data.aws_route53_zone.dns_private_zone.name}"]
  type    = "PTR"
  ttl     = "300"
}

resource "aws_ebs_volume" "k8sworker-volume1" {
  for_each = "${toset(var.k8sworker_machine_names)}"
  availability_zone = "${var.k8sworker_machine_azs[ each.value ]}"
  type              = "gp2"
  size              = 200
}

resource "aws_volume_attachment" "k8sworker-volume1-attachment" {
  for_each = "${toset(var.k8sworker_machine_names)}"
  device_name = "/dev/xvdb"
  instance_id = "${aws_instance.k8sworker-machine[ each.value ].id}"
  volume_id   = "${aws_ebs_volume.k8sworker-volume1[ each.value ].id}"
}
