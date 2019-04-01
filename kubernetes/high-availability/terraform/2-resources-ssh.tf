resource "tls_private_key" "privkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
