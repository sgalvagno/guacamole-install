#!/bin/bash

####################################################################
# Guacamole Install from GitHub on a new install of Ubuntu 16.04
#    with MySQL
#
# Sebastien Galvagno
# 09/11/2016
#
####################################################################

# some defines
mySQLConnectorVersion=5.1.40
defguacamolehome="/etc/guacamole"
deftomcathome="/opt/tomcat"

####################################################################

userHome=`pwd`
if [ ! -d ${userHome}/config ]
then
	mkdir ${userHome}/config
else
	echo "${userHome}/config already exist"
fi

####################################################################

function UpdateOS()
{
	echo "Updating OS"
	echo $mypassword | sudo -S apt-get update
}

####################################################################
# install dependencies
function InstallDependencies()
{
	echo "Downloading dependencies"
	echo $mypassword | sudo -S apt-get -y install libcairo2-dev
	echo $mypassword | sudo -S apt-get -y install libjpeg62-dev
	echo $mypassword | sudo -S apt-get -y install libpng12-dev
	echo $mypassword | sudo -S apt-get -y install libossp-uuid-dev

	####################################################################
	# Install libjpeg-turbo-dev
	# https://sourceforge.net/projects/libjpeg-turbo/files/
	wget -O libjpeg-turbo-official_1.5.1_amd64.deb http://downloads.sourceforge.net/project/libjpeg-turbo/1.5.1/libjpeg-turbo-official_1.5.1_amd64.deb
	echo $mypassword | sudo -S dpkg -i libjpeg-turbo-official_1.5.1_amd64.deb
}


####################################################################
# install optional dependencies
function InstallOptionalDependencies()
{
	echo "Downloading optional dependencies"
	echo $mypassword | sudo -S apt-get -y install libfreerdp-dev
	echo $mypassword | sudo -S apt-get -y install libpango1.0-dev
	echo $mypassword | sudo -S apt-get -y install libssh2-1-dev
	echo $mypassword | sudo -S apt-get -y install libtelnet-dev
	echo $mypassword | sudo -S apt-get -y install libvncserver-dev
	echo $mypassword | sudo -S apt-get -y install libpulse-dev
	echo $mypassword | sudo -S apt-get -y install libssl-dev
	echo $mypassword | sudo -S apt-get -y install libvorbis-dev
	echo $mypassword | sudo -S apt-get -y install libwebp-dev

	echo $mypassword | sudo -S apt-get -y install libavcodec-dev
	echo $mypassword | sudo -S apt-get -y install libavutil-dev
	echo $mypassword | sudo -S apt-get -y install libswscale-dev
}


####################################################################
# install MySQL
# http://dev.mysql.com/downloads/connector/j/
function InstallMySQL()
{
	echo
	echo
	export DEBIAN_FRONTEND="noninteractive"
	#echo $mypassword | sudo -S 'debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysqlrootpassword"'
	sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $mysqlrootpassword"
	sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $mysqlrootpassword"

	#echo $mypassword | sudo -S "echo mysql-server mysql-server/root_password password '$mysqlrootpassword' | debconf-set-selections"
	#echo $mypassword | sudo -S "echo mysql-server mysql-server/root_password_again password '$mysqlrootpassword' | debconf-set-selections"


	echo "Installing MySQL"
	echo $mypassword | sudo -S apt -y install mysql-server mysql-client
	echo
}

function SecurizingMySQL()
{
	echo
	echo "Securizing MySQL"
	echo $mypassword | sudo -S mysql_secure_installation --use-default -p$mysqlrootpassword
}

function InstallMySQLConnector()
{
	# install MySQL connector
	echo "Downloading MySQL connector (ver:$mySQLConnectorVersion) from Oracle"
	wget -O mysql-connector-java-${mySQLConnectorVersion}.tar.gz http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-$mySQLConnectorVersion.tar.gz
	tar zxvf mysql-connector-java-${mySQLConnectorVersion}.tar.gz
	
	if [ ! -d ${guacamolehome}/lib ]
	then 
		echo $mypassword | sudo -S mkdir -p ${guacamolehome}/lib
		echo $mypassword | sudo -S chmod 755 ${guacamolehome}/lib
	fi
	echo $mypassword | sudo -S cp mysql-connector-java-${mySQLConnectorVersion}/mysql-connector-java-${mySQLConnectorVersion}-bin.jar ${guacamolehome}/lib
	echo $mypassword | sudo -S chmod 700 ${guacamolehome}/lib
}

function InstallMysqlExtensioForGuacamole()
{
	# Configure Guacamole DB
	echo "Congiguring MySQL"
	# This is where you will want to change "guacdbuserpassword"
	# already done  - echo "mysql-password: $guacdbuserpassword" >> ${guacamolehome}/guacamole.properties
	# Create guacamole_db and grant guacamole_user permissions to it
	echo "create database guacamole_db; create user 'guacamole_user'@'localhost' identified by \"$guacdbuserpassword\";GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';flush privileges;" | mysql -u root -p$mysqlrootpassword
	cat ${userHome}/incubator-guacamole-client/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-mysql/schema/*.sql | mysql -u root -p$mysqlrootpassword guacamole_db

	if [ ! -d ${guacamolehome}/extensions ]
	then
		echo $mypassword | sudo -S mkdir -p ${guacamolehome}/extensions
		echo $mypassword | sudo -S chmod 755 ${guacamolehome}/extensions
	fi
	echo $mypassword | sudo -S cp ${userHome}/incubator-guacamole-client/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-mysql/target/guacamole-auth-jdbc-mysql-*-incubating.jar ${guacamolehome}/extensions/
	echo $mypassword | sudo -S chmod 700 ${guacamolehome}/extensions
}

####################################################################
# install JDK
function InstallJDK()
{
	echo "Installing JAVA"
	echo $mypassword | sudo -S apt-get -y install openjdk-8-jdk
	# define JAVA_HOME
	JAVA_HOME=`update-java-alternatives -l | awk '{print $3}'`"/jre"
	export JAVA_HOME
}

####################################################################
# Install Maven
function InstallMaven()
{
	echo "Installing Maven"
	echo $mypassword | sudo -S apt-get -y install maven
}


#####################################################################
# install Tomcat
# https://www.digitalocean.com/community/tutorials/how-to-install-apache-tomcat-8-on-ubuntu-16-04
function TomcatUpdateRight()
{
	# Update Permissions
	#cd /opt/tomcat
	echo $mypassword | sudo -S chgrp -R tomcat ${tomcathome}
	echo $mypassword | sudo -S chmod -R g+r ${tomcathome}/conf
	echo $mypassword | sudo -S chmod g+x ${tomcathome}/conf
	echo $mypassword | sudo -S chown -R tomcat ${tomcathome}/webapps/ ${tomcathome}/work/ ${tomcathome}/temp/ ${tomcathome}/logs/
}

function InstallTomcat()
{
	echo "Prepare system to receive tomcat"
	# First, create a new tomcat group:
	echo $mypassword | sudo -S groupadd tomcat
	# Next, create a new tomcat use
	echo $mypassword | sudo -S useradd -s /bin/false -g tomcat -d ${tomcathome} tomcat

	# Install Tomcat
	echo "Downloading Tomcat from Apache"
	# download
	curl -O http://apache.mirrors.ionfish.org/tomcat/tomcat-8/v8.5.5/bin/apache-tomcat-8.5.5.tar.gz
	# install
	echo "Installing Tomcat"
	echo $mypassword | sudo -S mkdir -p ${tomcathome}
	echo $mypassword | sudo -S tar xzvf apache-tomcat-8*tar.gz -C ${tomcathome} --strip-components=1
	
	TomcatUpdateRight
}



function ConfigureTomcat()
{
	echo "Creating config files"
	# Create a systemd Service File

	#echo $mypassword | sudo -S tee /etc/systemd/system/tomcat.service  <<-'EOF'
	echo $mypassword | sudo -S cat << EOF >> ${userHome}/config/tomcat.service

[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=$JAVA_HOME
Environment=CATALINA_PID=${tomcathome}/temp/tomcat.pid
Environment=CATALINA_HOME=${tomcathome}
Environment=CATALINA_BASE=${tomcathome}
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=${tomcathome}/bin/startup.sh
ExecStop=${tomcathome}/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target

EOF
	
	echo $mypassword | sudo -S cp ${userHome}/config/tomcat.service /etc/systemd/system/tomcat.service

	# open Firewall
	echo $mypassword | sudo -S ufw allow 8080	

# conf/tomcat-users.xml
# <user username="admin" password="asgtomcat" roles="manager-gui,admin-gui"/>

#awk '/<//tomcat-users>/ { print; print "<user username=\"admin\" password=\"asgtomcat\" roles=\"manager-gui,admin-gui\"\/>"; previous }1' ${tomcathome}/conf/tomcat-users.xml > ${tomcathome}/conf/tomcat-users.xml

awk '/<\/tomcat-users>/ { print "<user username=\"admin\" password=\"asgtomcat\" roles=\"manager-gui,admin-gui\"\/>"; previous;}1' ${tomcathome}/conf/tomcat-users.xml $> ${userHome}/config/tomcat-users.xml 

echo $mypassword | sudo -S cp ${userHome}/config/tomcat-users.xml ${tomcathome}/conf/tomcat-users.xml

####### To connect to Tomcat Administration page
# /opt/tomcat/webapps/host-manager/META-INF/context.xml
# comment restriction ip
#<!--<Valve className="org.apache.catalina.valves.RemoteAddrValve"
#         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" />-->
# or add yours like 10/8
#<Valve className="org.apache.catalina.valves.RemoteAddrValve"
#         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1|10\.\d+\.\d+\.\d+" />
}


function ConfigureTomcatForGuacamole()
{
	echo "Configuring Tomcat for Guacamole"

	# ####### default configuration file

	cat << EOF >> ${userHome}/config/tomcat8

# GUACAMOLE ENV VARIABLE
GUACAMOLE_HOME=$guacamolehome

EOF

echo $mypassword | sudo -S cp ${userHome}/config/tomcat8 /etc/default/tomcat8

echo $mypassword | sudo -S  ln -s /etc/guacamole /opt/tomcat/.guacamole	
}

#####################################################################

function BuildGuacd()
{
	#####################################################################
	# Guacd
	# load source from github
	echo "Loading guacd from GitHub"
	if [ ! -d https://github.com/apache/incubator-guacamole-server ]
	then
		git clone https://github.com/apache/incubator-guacamole-server
	else
		git pull https://github.com/apache/incubator-guacamole-server
	fi
	
	cd incubator-guacamole-server
	autoreconf --install
	#no-deprecated
	aclocal
	autoconf
	automake --add-missing
	./configure --with-init-dir=/etc/init.d
	# ./configure --with-init-dir=/etc/init.d --disable-warnings
	#--enable-Werror=no-deprecated-dependencies
	#./configure --with-init-dir=/etc/init.d --enable-Wno-error=pedantic --enable-Wno-error=deprecated-declarations --enable-Wno-deprecated --enable-Wno-deprecated-declarations
	
	# patch Makefile.am because there is a deprecated function
	cp src/protocols/rdp/Makefile.am src/protocols/rdp/Makefile.am.old
	awk '/guacdr_cflags/ { print; print "-Wno-error=deprecated-declarations \\"; next }1' src/protocols/rdp/Makefile.am > src/protocols/rdp/Makefile.am
	
	make
	echo $mypassword | sudo -S make install
	echo $mypassword | sudo -S ldconfig
	echo $mypassword | sudo -S systemctl enable guacd

	# ##### guacd.conf

	if [ ! -d ${guacamolehome} ]
	then
		echo $mypassword | sudo -S mkdir -p ${guacamolehome}
		echo $mypassword | sudo -S chmod 755 ${guacamolehome}
	fi

	echo $mypassword | sudo -S tee ${guacamolehome}/guacd.conf <<-'EOF'
#
# guacd configuration file
#

[daemon]

pid_file = /var/run/guacd.pid
log_level = info

[server]

bind_host = localhost
bind_port = 4822

#
# The following parameters are valid only if
# guacd was built with SSL support.
#

#[ssl]

#server_certificate = /etc/ssl/certs/guacd.crt
#server_key = /etc/ssl/private/guacd.key

EOF

	# ##### user-mapping.xml  to basic configuration, but dissable warning file not found it catalina.log

	echo $mypassword | sudo -S tee ${guacamolehome}/user-mapping.xml cat <<-'EOF'
<user-mapping>
</user-mapping>
EOF

	# ##### logback.xml (enable log & template)

	# Configure the log to debug mode

	echo $mypassword | sudo -S tee ${guacamolehome}/logback.xml <<-'EOF'
<configuration>

	<!-- Appender for debugging -->
    <appender name="GUAC-DEBUG" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>

    <!-- Log at DEBUG level -->
    <root level="debug">
        <appender-ref ref="GUAC-DEBUG"/>
    </root>

</configuration>
EOF

	# ### guacamole.properties file

	#echo $mypassword | sudo -S tee ${guacamolehome}/guacamole.properties <<-'EOF'
	cat << EOF >> ${userHome}/config/guacamole.properties
#
guacd-hostname: localhost
guacd-port: 4822

# MySQL properties
mysql-hostname: localhost
mysql-port: 3306
mysql-database: guacamole_db
mysql-username: guacamole_user
mysql-password: $guacdbuserpassword

EOF

	echo $mypassword | sudo -S cp ${userHome}/config/guacamole.properties ${guacamolehome}/guacamole.properties

	cd $userHome
}

####################################################################

function BuildGuacamole()
{
	######################################################################
	# guacamole-client
	#

	# load source from github
	# old repository
	#git clone git://github.com/glyptodon/guacamole-client.git
	#do not pass throw the proxy
	#git clone git://git.apache.org/incubator-guacamole-client.git
	if [ ! -d https://github.com/apache/incubator-guacamole-client ]
	then
		git clone https://github.com/apache/incubator-guacamole-client
	else
		git pull https://github.com/apache/incubator-guacamole-client
	fi

	cd incubator-guacamole-client

	#libtoolize
	#aclocal
	#autoconf
	#automake --add-missing

	mvn package

	cd $userHome
}

function ConfigureGuacamole()
{
	cd incubator-guacamole-client
	
	echo $mypassword | sudo -S cp ${userHome}/incubator-guacamole-client/guacamole/target/guacamole-*-incubating.war ${tomcathome}/webapps/guacamole.war

	# copy disabled modules
	if [ ! -d ${guacamolehome}/disabled-extensions ]
	then 
		echo $mypassword | sudo -S mkdir -p ${guacamolehome}/disabled-extensions
		echo $mypassword | sudo -S chmod 755 ${guacamolehome}/disabled-extensions
	fi
	echo $mypassword | sudo -S chmod 700 ${guacamolehome}/disabled-extensions
	
	echo $mypassword | sudo -S cp ${userHome}/incubator-guacamole-client/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-postgresql/target/guacamole-auth-jdbc-postgresql-*-incubating.jar ${guacamolehome}/disabled-extensions
	echo $mypassword | sudo -S cp ${userHome}/incubator-guacamole-client/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-dist/target/guacamole-auth-jdbc-dist-*-incubating.jar ${guacamolehome}/disabled-extensions
	echo $mypassword | sudo -S cp ${userHome}/incubator-guacamole-client/extensions/guacamole-auth-jdbc/modules/guacamole-auth-jdbc-base/target/guacamole-auth-jdbc-base-*-incubating.jar ${guacamolehome}/disabled-extensions
	echo $mypassword | sudo -S cp ${userHome}/incubator-guacamole-client/extensions/guacamole-auth-ldap/target/guacamole-auth-ldap-*-incubating.jar ${guacamolehome}/disabled-extensions
	echo $mypassword | sudo -S cp ${userHome}/incubator-guacamole-client/extensions/guacamole-auth-noauth/target/guacamole-auth-noauth-*-incubating.jar ${guacamolehome}/disabled-extensions
	
	cd $userHome
}

###############################################################################################

###################### ask for password and path ##############################################

# Grap password for sudo command
read -s -p "Enter your password to sudo the command:" mypassword
echo
if [ $mypassword == "" ]; then echo "You need to enter your password to execute sudo command!"; exit 1 ; fi

# Grap Guacamole path folder 
read -e -i "$defguacamolehome" -p "Enter the Guacamole home folder: " guacamolehome
guacamolehome=${guacamolehome:-$defguacamolehome}
echo "Installing Guacamole into: $guacamolehome folder"
export GUACAMOLE_HOME=$guacamolehome

# Grap Guacamole path folder 
read -e -i "$deftomcathome" -p  "Enter the Tomcat home folder: " tomcathome
echo
tomcathome=${tomcathome:-$deftomcathome}
export TOMCAT_HOME=$tomcathome
echo "Installing Tomcat into: $tomcathome folder"

# Grab a password for MySQL Root
read -s -p "Enter the password that will be used for MySQL Root: " mysqlrootpassword
echo

echo

# Grab a password for Guacamole Database User Account
read -s -p "Enter the password that will be used for the Guacamole database: " guacdbuserpassword
echo


####################################################################
UpdateOS

InstallDependencies
InstallOptionalDependencies

#exit 0

InstallMySQL
InstallMySQLConnector

InstallJDK
InstallMaven
InstallTomcat

#exit 0
ConfigureTomcat

BuildGuacd
BuildGuacamole

#exit 0

InstallMysqlExtensioForGuacamole
ConfigureGuacamole
ConfigureTomcatForGuacamole
echo $mypassword | sudo -S chmod -R ga+rx ${guacamolehome}
TomcatUpdateRight

#SecurizingMySQL

echo $mypassword | sudo -S systemctl daemon-reload
echo $mypassword | sudo -S service tomcat restart
echo $mypassword | sudo -S service guacd restart

# The End

IP=`ifconfig|awk '/inet 10./ {  print $2 }'`

echo "now you could connect on http://$IP:8080/guacamole"
echo "use login guacadmin and password guacadmin"
echo ""


exit 0

#####################################################################
#####################################################################
