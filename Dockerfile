FROM ubuntu:16.04

MAINTAINER R&D <rnd@runsystem.net>

# Add config file
ADD /root /
 
# update & upgrade
RUN apt-get update && apt-get upgrade -y

# Install common tools
RUN apt-get install -y \
        wget \
        curl \
        vim

#-------------------------------------------------------------------------------
# Install supervisord for service management
#-------------------------------------------------------------------------------
RUN apt-get -y install supervisor 

#-------------------------------------------------------------------------------
# SSH
#-------------------------------------------------------------------------------
RUN apt-get -y install openssh-server && \
    mkdir /var/run/sshd && \
    echo 'root:runsystem' | chpasswd && \
    # Allow root login
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    # SSH login fix. Otherwise user is kicked off after login
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
    # Config start ssh daemon using supervisord

#-------------------------------------------------------------------------------
# Tomcat
#-------------------------------------------------------------------------------
# Install jdk
RUN apt-get install -y default-jdk

# Create tomcat group
RUN groupadd tomcat

# Create a new tomcat user is member of the tomcat group, with a home directory of /opt/tomcat 
# And with a shell of /bin/false (so nobody can log into the account)
RUN useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

# Download tomcat
RUN cd /tmp && \
    wget http://archive.apache.org/dist/tomcat/tomcat-8/v8.5.5/bin/apache-tomcat-8.5.5.tar.gz

# Install tomcat
RUN mkdir /opt/tomcat && \
    tar xzvf /tmp/apache-tomcat-8.5.5.tar.gz -C /opt/tomcat --strip-components=1
VOLUME "/opt/tomcat/webapps"
WORKDIR /opt/tomcat

# update permission
    # Give the tomcat group ownership over the entire installation directory
RUN chgrp -R tomcat /opt/tomcat && \
    # Give the tomcat group read access to the conf directory and all of its contents, and execute access to the directory itself
    chmod -R g+r conf && \
    chmod g+x conf && \
    # Make the tomcat user the owner of the webapps, work, temp, and logs directories
    chown -R tomcat webapps/ work/ temp/ logs/

#-------------------------------------------------------------------------------
# Install mysql 5.7
#-------------------------------------------------------------------------------
RUN echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
RUN echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections

RUN apt-get -y install mysql-server-5.7 && \
	mkdir -p /var/lib/mysql && \
	mkdir -p /var/run/mysqld && \
	mkdir -p /var/log/mysql && \
	chown -R mysql:mysql /var/lib/mysql && \
	chown -R mysql:mysql /var/run/mysqld && \
	chown -R mysql:mysql /var/log/mysql

# UTF-8 and bind-address
RUN sed -i -e "$ a [client]\n\n[mysql]\n\n[mysqld]"  /etc/mysql/my.cnf && \
	sed -i -e "s/\(\[client\]\)/\1\ndefault-character-set = utf8/g" /etc/mysql/my.cnf && \
	sed -i -e "s/\(\[mysql\]\)/\1\ndefault-character-set = utf8/g" /etc/mysql/my.cnf && \
	sed -i -e "s/\(\[mysqld\]\)/\1\ninit_connect='SET NAMES utf8'\ncharacter-set-server = utf8\ncollation-server=utf8_unicode_ci\nbind-address = 0.0.0.0/g" /etc/mysql/my.cnf

# Clean temp file
RUN rm -rf /tmp/*
ADD context.xml /opt/tomcat/webapps/manager/META-INF/
ADD tomcat-users.xml /opt/tomcat/conf/
# Label
LABEL "tomcat"="TRUE"
LABEL "mysql"="TRUE"
LABEL "ssh"="TRUE"


EXPOSE 22 8080 80 3306

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]
