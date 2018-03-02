variable "aws_ssh_admin_key_file" { }
variable "aws_key_name" {}
variable "instance_type" {
  description = "AWS Instance Type."
  default     = "t2.micro"
}
