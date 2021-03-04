# k8smaster variables
variable "k8smaster_machine_names" {
  description = "Host names for k8smaster machines"
  type = list(string)
  default = ["k8smaster000","k8smaster001","k8smaster002"]
}

variable "k8smaster_machine_subnets" {
  description = "Subnet where each host is to be provisioned"
  type = "map"
  default = {
    "k8smaster000" = "AAAAA-useast1-private-us-east-1a-sn"
    "k8smaster001" = "AAAAA-useast1-private-us-east-1a-sn"
    "k8smaster002" = "AAAAA-useast1-private-us-east-1a-sn"
  }
}

variable "k8smaster_machine_ips" {
  description = "Static Private IP Address for each host"
  type = "map"
  default = {
    "k8smaster000" = "IP-ADDR-HERE"
    "k8smaster001" = "IP-ADDR-HERE"
    "k8smaster002" = "IP-ADDR-HERE"
  }
}

variable "k8smaster_machine_ansible_group" {
  default = "k8smaster"
}

# k8smaster MACHINE
resource "aws_instance" "k8smaster-machine" {
  for_each          = "${toset(var.k8smaster_machine_names)}"
  ami               = "${var.amis["AMI-NAME-HERE"]}"
  instance_type     = "${var.instance_type["large"]}"
  iam_instance_profile = "IAM-ROLE-HERE"

  key_name          = "${var.keypairs["kp_1"]}"
  subnet_id         = "${var.subnets[ var.k8smaster_machine_subnets[ each.value ] ]}"

  private_ip        = "${var.k8smaster_machine_ips[ each.value ]}"
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
    AnsibleRole = "k8smaster"
    ClusterRole = "none"
  }
}


resource "aws_route53_record" "k8smaster-machine-private-record" {
  for_each = "${toset(var.k8smaster_machine_names)}"
  zone_id  = "${data.aws_route53_zone.dns_private_zone.zone_id}"
  name     = "${each.value}.${data.aws_route53_zone.dns_private_zone.name}"
  type     = "A"
  ttl      = "300"
  records = ["${var.k8smaster_machine_ips[ each.value ]}"]
}


resource "aws_route53_record" "k8smaster-machine-reverse-record" {
  for_each = "${toset(var.k8smaster_machine_names)}"
  zone_id = "${data.aws_route53_zone.dns_reverse_zone.zone_id}"
  name    = "${element(split(".", var.k8smaster_machine_ips[ each.value ]),3)}.${element(split(".", var.k8smaster_machine_ips[ each.value ]),2)}.${data.aws_route53_zone.dns_reverse_zone.name}"
  records = ["${each.value}.${data.aws_route53_zone.dns_private_zone.name}"]
  type    = "PTR"
  ttl     = "300"
}


resource "aws_elb" "k8smaster-elastic-load-balancer" {
  name    = "k8smaster-elastic-load-balancer"
  subnets = [
    "${var.subnets[ var.k8smaster_machine_subnets[ "k8smaster000" ] ]}",
    "${var.subnets[ var.k8smaster_machine_subnets[ "k8smaster001" ] ]}",
    "${var.subnets[ var.k8smaster_machine_subnets[ "k8smaster002" ] ]}"
  ]

  security_groups = [
    "${var.secgroups["management001useast1-cluster-security-group"]}"
  ]

  #access_logs {
  #  bucket        = "foo"
  #  bucket_prefix = "bar"
  #  interval      = 60
  #}

  listener {
    instance_port      = 6443
    instance_protocol  = "TCP"
    lb_port            = 6443
    lb_protocol        = "TCP"
  }

  /*listener {
    instance_port      = 30000
    instance_protocol  = "http"
    lb_port            = 8080
    lb_protocol        = "http"
    #ssl_certificate_id = "arn:aws:acm:us-east-1:004121356543:certificate/cb10d8b9-a667-48e4-95d4-bd74d2579e78"
  }*/

  /*listener {
    instance_port      = 30001
    instance_protocol  = "http"
    lb_port            = 8081
    lb_protocol        = "http"
    #ssl_certificate_id = "arn:aws:acm:us-east-1:004121356543:certificate/cb10d8b9-a667-48e4-95d4-bd74d2579e78"
  }*/

  /*listener {
    instance_port      = 30003
    instance_protocol  = "http"
    lb_port            = 80
    lb_protocol        = "http"
    //ssl_certificate_id = "arn:aws:acm:us-east-1:004121356543:certificate/cb10d8b9-a667-48e4-95d4-bd74d2579e78"
  }*/

  /*listener {
    instance_port      = 30004
    instance_protocol  = "https"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "arn:aws:acm:us-east-1:004121356543:certificate/cb10d8b9-a667-48e4-95d4-bd74d2579e78"
  }*/

  /*listener {
    instance_port      = 30005
    instance_protocol  = "http"
    lb_port            = 8082
    lb_protocol        = "http"
  }*/

  instances = [
    "${aws_instance.k8smaster-machine["k8smaster000"].id}",
    "${aws_instance.k8smaster-machine["k8smaster001"].id}",
    "${aws_instance.k8smaster-machine["k8smaster002"].id}"
  ]

  internal = true
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "k8smaster-elastic-load-balancer"
  }
}

resource "aws_route53_record" "k8smaster-elastic-load-balancer-private-record" {
  zone_id  = "${data.aws_route53_zone.dns_private_zone.zone_id}"
  name     = "k8sapi.${data.aws_route53_zone.dns_private_zone.name}"
  ttl      = "300"

  # Should be A record prior to bootstrapping all control plane nodes
  type     = "A"
  records  = ["${aws_instance.k8smaster-machine["k8smaster000"].private_ip}"]

  # Toggle to CNAME record control plane is up and all nodes healthy in elb
  #type    = "CNAME"
  #records = ["${aws_elb.k8smaster-elastic-load-balancer.dns_name}"]
}

/*resource "aws_route53_record" "jenkins-private-record" {
  zone_id  = "${data.aws_route53_zone.dns_private_zone.zone_id}"
  name     = "jenkins.${data.aws_route53_zone.dns_private_zone.name}"
  ttl      = "300"
  type    = "CNAME"
  records = ["${aws_elb.k8smaster-elastic-load-balancer.dns_name}"]
}*/

/*resource "aws_route53_record" "sonarqube-private-record" {
  zone_id  = "${data.aws_route53_zone.dns_private_zone.zone_id}"
  name     = "sonarqube.${data.aws_route53_zone.dns_private_zone.name}"
  ttl      = "300"
  type    = "CNAME"
  records = ["${aws_elb.k8smaster-elastic-load-balancer.dns_name}"]
}*/

/*resource "aws_route53_record" "argocd-private-record" {
  zone_id  = "${data.aws_route53_zone.dns_private_zone.zone_id}"
  name     = "argocd.${data.aws_route53_zone.dns_private_zone.name}"
  ttl      = "300"
  type    = "CNAME"
  records = ["${aws_elb.k8smaster-elastic-load-balancer.dns_name}"]
}*/

/*resource "aws_route53_record" "grafana-private-record" {
  zone_id  = "${data.aws_route53_zone.dns_private_zone.zone_id}"
  name     = "grafana.${data.aws_route53_zone.dns_private_zone.name}"
  ttl      = "300"
  type    = "CNAME"
  records = ["${aws_elb.k8smaster-elastic-load-balancer.dns_name}"]
}*/


/*resource "aws_elb" "app-elb" {
  name    = "app-elb"
  subnets = [
    "${var.subnets["AAAAA-useast1-public-us-east-1a-sn"]}"
  ]

  security_groups = [
    "${var.secgroups["AAAAA-useast1-cluster-security-group"]}"
  ]

  //listener {
  //  instance_port      = 30000
  //  instance_protocol  = "http"
  //  lb_port            = 443
  //  lb_protocol        = "https"
  //  ssl_certificate_id = "arn:aws:acm:us-east-1:004121356543:certificate/cb10d8b9-a667-48e4-95d4-bd74d2579e78"
  //}

  instances = [
    "${aws_instance.k8smaster-machine["k8smaster000"].id}",
    "${aws_instance.k8smaster-machine["k8smaster001"].id}",
    "${aws_instance.k8smaster-machine["k8smaster002"].id}"
  ]

  internal = false
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "app-elb"
  }
}*/


/*resource "aws_route53_record" "jenkins-public-record" {
  zone_id  = "${data.aws_route53_zone.dns_public_zone.zone_id}"
  name     = "jenkins.webhook.${data.aws_route53_zone.dns_public_zone.name}"
  ttl      = "300"
  # Toggle to CNAME record control plane is up and all nodes healthy in elb
  type    = "CNAME"
  records = ["${aws_elb.app-elb.dns_name}"]
}*/


output "k8smaster-elastic-load-balancer-ip" {
  value = "${aws_elb.k8smaster-elastic-load-balancer.dns_name}"
}


/*output "app-elb" {
  value = "${aws_elb.app-elb.dns_name}"
}*/
