FROM centos:centos6

MAINTAINER Jeffrey Lee <jlee@frenchquarterit.com>

# Set versions for Ruby, Rails, and Passenger
ENV RUBY_VERSION 2.1.0
ENV RAILS_VERSION 4.0.0
ENV PASSENGER_VERSION 4.0.37

# Import the Centos-6 RPM GPG key to prevent warnings
RUN rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-6

# Add EPEL Repository
RUN rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6
RUN rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

# Update Yum packages
RUN yum -y update

# Install base package set
RUN yum -y install nano sudo openssh openssh-server openssh-clients wget git \
    openssl openssl-devel python-pip

# Clean up
RUN yum clean all

# Install supervisord (required to run more than a single process in a container)
# Note: EPEL package lacks /usr/bin/pidproxy
# We require supervisor-stdout to allow output of services started by
# supervisord to be easily inspected with "docker logs".
RUN pip install --upgrade 'pip >= 1.4, < 1.5'
RUN pip install --upgrade supervisor supervisor-stdout
RUN mkdir -p /var/log/supervisor/

# Configure SSH for non-root public key authentication
RUN sed -i \
    -e 's/^UsePAM yes/#UsePAM yes/g' \
    -e 's/^#UsePAM no/UsePAM no/g' \
    -e 's/^PasswordAuthentication yes/PasswordAuthentication no/g' \
    -e 's/^#PermitRootLogin yes/PermitRootLogin no/g' \
    -e 's/^#UseDNS yes/UseDNS no/g' \
    /etc/ssh/sshd_config

# Enable the wheel sudoers group
RUN sed -i 's/^# %wheel\tALL=(ALL)\tALL/%wheel\tALL=(ALL)\tALL/g' /etc/sudoers

# Make the custom configuration directory
RUN mkdir -p /etc/services-config/{supervisor,ssh}

# Add default authorized keys - these will be copied into place by the bootstrap script
ADD authorized_keys /etc/services-config/ssh/

# Add default supervisord configuration and link to default file system location
ADD supervisord.conf /etc/services-config/supervisor/
RUN ln -sf /etc/services-config/supervisor/supervisord.conf /etc/supervisord.conf

# Add default sshd configuration and link to default file system location
ADD sshd_config /etc/services-config/ssh/
RUN chmod 600 /etc/services-config/ssh/sshd_config
RUN ln -sf /etc/services-config/ssh/sshd_config /etc/ssh/sshd_config

# Add default bootstrap configuration and link to default file system location
ADD ssh-bootstrap.conf /etc/services-config/ssh/
RUN ln -sf /etc/services-config/ssh/ssh-bootstrap.conf /etc/ssh-bootstrap.conf

ADD ssh-bootstrap /etc/
RUN chmod +x /etc/ssh-bootstrap

# Create gemrc file
RUN echo "gem: --no-rdoc --no-ri" > /etc/gemrc

# Purge
RUN rm -rf /etc/ld.so.cache
RUN rm -rf /sbin/sln
RUN rm -rf /usr/{{lib,share}/locale,share/{man,doc,info,gnome/help,cracklib,il8n},{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive}
RUN rm -rf /var/cache/ldconfig/*
RUN rm -rf /var/cache/yum/*

EXPOSE 22
EXPOSE 80
EXPOSE 443

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]
