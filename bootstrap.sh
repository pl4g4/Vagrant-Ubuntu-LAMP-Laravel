#!/usr/bin/env bash
 
# ---------------------------------------
#          Virtual Machine Setup
# ---------------------------------------

SERVERNAME="locahost"
MYSQLPASSWORD="root"
DBNAME="canada"
DBUSER="canada"
DBPD="canada"
WEBPUBLICFOLDER="/var/www/laravel/public"
 
# Adding multiverse sources.
cat > /etc/apt/sources.list.d/multiverse.list << EOF
deb http://archive.ubuntu.com/ubuntu trusty multiverse
deb http://archive.ubuntu.com/ubuntu trusty-updates multiverse
deb http://security.ubuntu.com/ubuntu trusty-security multiverse
EOF
 
 
# Updating packages
apt-get update
 
# ---------------------------------------
#          Apache Setup
# ---------------------------------------
 
# Installing Packages
apt-get install -y apache2 libapache2-mod-fastcgi apache2-mpm-worker


# linking Vagrant directory to Apache 2.4 public directory
rm -rf /var/www
ln -fs /vagrant /var/www
 
# Add ServerName to httpd.conf
echo "ServerName ${SERVERNAME}" > /etc/apache2/httpd.conf

# Setup hosts file
VHOST=$(cat <<EOF
<VirtualHost *:80>
  DocumentRoot "{$WEBPUBLICFOLDER}"
  ServerName $SERVERNAME
  <Directory "${WEBPUBLICFOLDER}">
    Order allow,deny
    Allow from all
    Require all granted
  </Directory>
</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-enabled/000-default.conf

tee -a /etc/hosts <<EOL
127.0.0.1 ${SERVERNAME}
EOL
 
# Loading needed modules to make apache work
a2enmod actions fastcgi rewrite
service apache2 reload
 
# ---------------------------------------
#          PHP Setup
# ---------------------------------------
 
# Installing packages
apt-get install -y php5 php5-cli php5-fpm curl php5-curl php5-mcrypt php5-xdebug
 
# Creating the configurations inside Apache
cat > /etc/apache2/conf-available/php5-fpm.conf << EOF
<IfModule mod_fastcgi.c>
    AddHandler php5-fcgi .php
    Action php5-fcgi /php5-fcgi
    Alias /php5-fcgi /usr/lib/cgi-bin/php5-fcgi
    FastCgiExternalServer /usr/lib/cgi-bin/php5-fcgi -socket /var/run/php5-fpm.sock -pass-header Authorization
 
    # NOTE: using '/usr/lib/cgi-bin/php5-cgi' here does not work,
    #   it doesn't exist in the filesystem!
    <Directory /usr/lib/cgi-bin>
        Require all granted
    </Directory>
 
</IfModule>
EOF
 
# Enabling php modules
php5enmod mcrypt
 
# Triggering changes in apache
a2enconf php5-fpm
service apache2 reload
 
# ---------------------------------------
#          MySQL Setup
# ---------------------------------------
 
# Setting MySQL root user password root/root
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password ${MYSQLPASSWORD}"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${MYSQLPASSWORD}"
 
# Installing packages
apt-get install -y mysql-server mysql-client php5-mysql

MYSQL= `which mysql`

Q1="GRANT ALL ON *.* TO 'root'@'localhost' IDENTIFIED BY '$MYSQLPASSWORD' WITH GRANT OPTION;"
Q2="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}"

$MYSQL -uroot -proot -e "${SQL}"

service mysql restart
 
# ---------------------------------------
#          PHPMyAdmin setup
# ---------------------------------------
 
# Default PHPMyAdmin Settings
debconf-set-selections <<< 'phpmyadmin phpmyadmin/dbconfig-install boolean true'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/app-password-confirm password root'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/admin-pass password root'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/mysql/app-pass password root'
debconf-set-selections <<< 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2'
 
# Install PHPMyAdmin
apt-get install -y phpmyadmin
 
# Make phpmyadmin available globally
ln -s /etc/phpmyadmin/apache.conf /etc/apache2/sites-enabled/phpmyadmin.conf
 
# Restarting apache to make changes
service apache2 restart
 
# ---------------------------------------
#       Tools Setup
# ---------------------------------------
 
# Installing GIT
apt-get install -y git

# Install Vim
apt-get install -y vim

# Install nano
apt-get install -y nano
 
# Install Composer
curl -s https://getcomposer.org/installer | php
 
# Make Composer available globally
mv composer.phar /usr/local/bin/composer

#change directory to webroot
cd /var/www

#install laravel if not installed
if [ ! -d "laravel" ]; then
  composer create-project laravel/laravel --prefer-dist
fi

# Set up the database
DB="create database if not exists ${DBNAME} ;GRANT ALL PRIVILEGES ON ${DBNAME}.* TO ${DBUSER}@localhost IDENTIFIED BY '${DBPD}';FLUSH PRIVILEGES;"
$MYSQL -uroot -proot -e "${DB}"
 
if [ $? != "0" ]; then
 echo "[Error]: Database creation failed"
 exit 1
else
 echo " Database has been created successfully "
fi

