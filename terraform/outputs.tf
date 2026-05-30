output "public_ip" {
  description = "Public IP of the box. Point your DNS A record here."
  value       = var.create_eip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip
}

output "public_dns" {
  description = "AWS-assigned public DNS name."
  value       = aws_instance.app.public_dns
}

output "instance_id" {
  value = aws_instance.app.id
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}

output "instance_role_arn" {
  value = aws_iam_role.instance.arn
}

output "next_steps" {
  description = "What to do after apply."
  value       = <<-EOT

    1. Point DNS for '${var.site_address}' at the public_ip above
       (or set site_address to '<public_ip>.sslip.io' and skip DNS).
    2. Give the box a minute, then open https://${var.site_address}
    3. Shell in to set PORTAL_PASSWORD / SMTP:
         - with SSH:  ssh ec2-user@${var.site_address}
         - or no key: AWS console > the instance > Connect > Session Manager
       then:  sudo nano /opt/setu/app/.env.${var.environment} && (cd /opt/setu/app && ./deploy.sh ${var.environment})
  EOT
}
