#!/bin/bash

# Оголошення змінних

# Публічна IP адреса для EC2 (значення отримується в outputs після виконання IaC terraform)
EC2_HOST="<ec2-public-ip>"

# Значення змінних для MySQL RDS (Endpoint отримується в outputs після виконання IaC terraform)
DB_NAME="wordpress"
DB_USER="admin"
DB_PASSWORD="passw0rd_123"
DB_HOST="<rds-endpoint>"

# Значення змінних для ElastiCache Redis (Endpoint отримується в outputs після виконання IaC terraform)
WP_REDIS_HOST="<elasticache_endpoint>"
WP_REDIS_PORT="6379"

# Встановлення необхідних пакетів
sudo apt update
sleep 5
sudo apt install apache2 php php-mysql -y
sleep 5

# Встановлення wp-cli
sudo wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp
sleep 5
sudo chmod +x /usr/local/bin/wp

# Зміна власника файлу /var/www/html для можливості запуску команди wp
sudo chown -R www-data:www-data /var/www/html

# Завантаження необхідних файлів Wordpress
sudo -u www-data wp core download --path=/var/www/html
sleep 5

# Створення конфігураційного файлу wp-config.php з вказанням змінних MySQL RDS та Elasticache Redis
sudo -u www-data wp config create \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASSWORD" \
    --dbhost="$DB_HOST" \
    --path=/var/www/html \
    --extra-php <<PHP
define( 'WP_CACHE', 'true' );
define( 'WP_REDIS_HOST', '$WP_REDIS_HOST' );
define( 'WP_REDIS_PORT', '$WP_REDIS_PORT' );
PHP

sleep 5

# Встановлення Wordpress (значення вказані тестові, можна не змінювати)
sudo -u www-data wp core install \
    --url="http://$EC2_HOST" \
    --title="Wordpress" \
    --admin_user="admin" \
    --admin_password="passw0rd_123" \
    --admin_email="test@ops.com" \
    --skip-email \
    --path=/var/www/html
sleep 5

# Встановлення та активація плагіна для Redis
sudo -u www-data wp plugin install redis-cache --activate --path=/var/www/html
sleep 5

# Видалення файлу за замовчуванням та рестартуємо apache
sudo rm -rf /var/www/html/index.html
sudo systemctl restart apache2