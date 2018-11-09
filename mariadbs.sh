sudo pacman -S mariadb --noconfirm --needed
read -p "Write an user for the database (mysql by default):" USERDB
USERDB="${USERDB:=mysql}"
useradd $USERDB
echo "Creating terminal for $USERDB"
sudo chsh -s /bin/bash $USERDB
sudo passwd $USERDB
echo "Open mysqld on a new terminal"
echo "And check the port and the socket"
echo "Edit /etc/mysql/my.cnf and add skip-grant-tables below [mysqld]"
echo "Edit and add echo "socket=/run/mysqld/mysqld.sock" >>$config at the make_config() before sed"
echo "Execute mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql"
echo "Execute mysql -u $USERDB -p"
echo "See db and tables with show databases; and show tables;"
su - mysql
