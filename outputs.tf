# Публічна IP адреса EC2 інстанса
output "ec2_public_ip" {
  value = aws_instance.ec2_instance.public_ip
}

# Endpoint для MySQL RDS (без вказання порту)
output "mysql_rds_endpoint" {
  value = replace(aws_db_instance.mysql_rds_instance.endpoint, ":${aws_db_instance.mysql_rds_instance.port}", "")
}

# Endpoint для ElastiCache Redis
output "elasticache_redis_endpoint" {
  value = aws_elasticache_cluster.elasticache_redis.cache_nodes.0.address
}