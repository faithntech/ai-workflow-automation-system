output "elastic_ip" {
    value = aws_eip.automation_eip.public_ip
}

output "ssh_command" {
    value = "ssh -i key-pair/ai-automation-key ubuntu@${aws_eip.automation_eip.public_ip}"
}

output "n8n_url" {
    value = "http://${aws_eip.automation_eip.public_ip}:5678"
}