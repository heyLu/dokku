DOKKU_VERSION = master

SSHCOMMAND_URL ?= https://raw.github.com/progrium/sshcommand/master/sshcommand
PLUGINHOOK_URL ?= https://s3.amazonaws.com/progrium-pluginhook/pluginhook_0.1.0_amd64.deb
STACK_URL ?= https://github.com/progrium/buildstep.git
PREBUILT_STACK_URL ?= https://github.com/progrium/buildstep/releases/download/2014-03-08/2014-03-08_429d4a9deb.tar.gz
DOKKU_ROOT ?= /home/dokku

PREFIX ?= /usr

.PHONY: all install copyfiles version plugins dependencies sshcommand pluginhook docker aufs stack count

all:
	# Type "make install" to install.

install: dependencies stack copyfiles plugins version

copyfiles: addman
	cp dokku ${PREFIX}/bin/dokku
	mkdir -p /var/lib/dokku/plugins
	cp -r plugins/* /var/lib/dokku/plugins

addman:
	mkdir -p ${PREFIX}/share/man/man1
	cp dokku.1 ${PREFIX}/share/man/man1/dokku.1
	mandb

version:
	git describe --tags > ${DOKKU_ROOT}/VERSION  2> /dev/null || echo '~${DOKKU_VERSION} ($(shell date -uIminutes))' > ${DOKKU_ROOT}/VERSION

plugins: pluginhook docker
	dokku plugins-install

dependencies: sshcommand pluginhook docker stack

sshcommand:
	if [[ ! -d "sshcommand" ]]; then git clone git://github.com/progrium/sshcommand; fi
	cp sshcommand/sshcommand ${PREFIX}/bin
	sshcommand create dokku ${PREFIX}/bin/dokku

pluginhook:
	if [[ ! -d "pluginhook" ]]; then git clone git://github.com/progrium/pluginhook; fi
	if [[ ! -e "pluginhook/pluginhook" ]]; then \
		cd pluginhook && GOPATH=`pwd` go get -d . && GOPATH=`pwd` go build && cd -; \
	fi
	cp pluginhook/pluginhook ${PREFIX}/bin

docker:
	egrep -i "^docker" /etc/group || groupadd docker
	usermod -aG docker dokku

stack:
ifdef BUILD_STACK
	@docker images | grep progrium/buildstep || (git clone ${STACK_URL} /tmp/buildstep && docker build -t progrium/buildstep /tmp/buildstep && rm -rf /tmp/buildstep)
else
	@docker images | grep progrium/buildstep || curl -L ${PREBUILT_STACK_URL} | gunzip -cd | docker import - progrium/buildstep
endif

count:
	@echo "Core lines:"
	@cat dokku bootstrap.sh | wc -l
	@echo "Plugin lines:"
	@find plugins -type f | xargs cat | wc -l
	@echo "Test lines:"
	@find tests -type f | xargs cat | wc -l
