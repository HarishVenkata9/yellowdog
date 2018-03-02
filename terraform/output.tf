output "elb_endpoint" {
  value = "${aws_elb.yellowdog_lb.dns_name}"
}
