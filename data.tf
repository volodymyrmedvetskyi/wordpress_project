# Остання версія Ubuntu для EC2 інстансу
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu-*"]
  }
}