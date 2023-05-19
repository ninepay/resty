#!/bin/bash

VIRTUALENV_VER=20.17.1

SUPERVISOR_VER=4.2.4

REDIS_VER=7.0.11
SSDB_VER=master

# http://kr.github.io/beanstalkd/
BEANSTALKD_VER=1.10.1
# https://github.com/diegonehab/luasocket
#LUASOCKET_VER=3.0-rc1
LUASOCKET_VER=3.1.0
# https://github.com/cloudwu/lua-bson
LUABSON_VER=20160519
# https://github.com/cloudwu/pbc
LUAPBC_VER=20160531
# https://github.com/mah0x211/lua-process
#LUAPROCESS_VER=1.6.0
LUAPROCESS_VER=1.7.0

SRC_DIR=$1
#$(cd "$(dirname $0)" && pwd)

echo "SRC_DIR   = $SRC_DIR"

# default configs
DEST_DIR=$2
#SRC_DIR

# ARGS=$(getopt -o h --long help,prefix: -n 'Install GameBox Cloud Core' -- "$@")

# eval set -- "$ARGS"

NEED_COPY_FILES=1
if [ "$DEST_DIR" == "$SRC_DIR" ]; then
	NEED_COPY_FILES=0
fi

echo "NEED_COPY_FILES = $NEED_COPY_FILES"

mkdir -pv $DEST_DIR

if [ $? -ne 0 ]; then
	echo "DEST_DIR  = $DEST_DIR"
	echo ""
	echo "\033[31mCreate install dir failed.\033[0m"
	exit 1
fi

cd $DEST_DIR
DEST_DIR=$(pwd)
#$(pwd)
echo "DEST_DIR  = $DEST_DIR"

BUILD_DIR=$SRC_DIR/build/install
mkdir -p $BUILD_DIR
echo "BUILD_DIR = $BUILD_DIR"
echo ""

DEST_BIN_DIR=$DEST_DIR

SED_BIN='sed -i'

set -e

#rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR
#cp -f $SRC_DIR/build/*.tar.gz $BUILD_DIR

mkdir -p $DEST_DIR
mkdir -p $DEST_BIN_DIR/bin

cd $BUILD_DIR

_env() {
    apk add --no-cache --virtual .build-deps \
	libc6-compat \
        build-base \
        coreutils \
        curl \
	wget \
        gd-dev \
        geoip-dev \
        libxslt-dev \
        linux-headers \
        make \
        perl-dev \
        readline-dev \
    zlib-dev

#    apk add --no-cache py3-virtualenv py3-pip python3 supervisor \
    #apk add --no-cache python2 py-virtualenv py-pip \
	apk add supervisor autoconf libtool automake bash rsync git gd geoip libgcc libxslt zlib 

}
_env_gbc(){
	# ----
	# install virtualenv and supervisor
	echo ""
	echo -e "[\033[32mINSTALL\033[0m] virtualenv"
	cd $BUILD_DIR

	#	sudo apt install -y luajit libluajit-5.1-dev
	#rm ~/.asdf/shims/python*

	# tar xfz $SRC_DIR/build/install/virtualenv-$VIRTUALENV_VER.tar.gz
	PYTHON_ENV_DIR=$DEST_BIN_DIR/bin/python_env
	# rm -fr $PYTHON_ENV_DIR
	# mv virtualenv-$VIRTUALENV_VER $PYTHON_ENV_DIR
	mkdir -p $PYTHON_ENV_DIR
	cd $PYTHON_ENV_DIR

	# python virtualenv.py --no-download gbc
	virtualenv --no-download gbc
	cd gbc
	source bin/activate
	pip install supervisor

	# curl https://bootstrap.pypa.io/pip/2.7/get-pip.py | python
	#	curl https://bootstrap.pypa.io/get-pip.py | python
# 	echo ""
# 	echo -e "[\033[32mINSTALL\033[0m] supervisor"
# 	cd $BUILD_DIR
# 	tar zxf $SRC_DIR/build/install/supervisor-$SUPERVISOR_VER.tar.gz
# 	cd supervisor-$SUPERVISOR_VER
# 	$SED_BIN "/zip_ok = false/a\\
# index-url = http://mirrors.aliyun.com/pypi/simple/" setup.cfg
# 	python setup.py install
}
_ssdb() {
	# ----
	#install redis
	echo ""
	echo -e "[\033[32mINSTALL\033[0m] ssdb"

apk add --no-cache --virtual .build-deps \
      curl gcc g++ make autoconf libc-dev libevent-dev linux-headers perl tar \
    && mkdir -p /tmp/ssdb \
    && curl -Lk "https://github.com/ideawu/ssdb/archive/${SSDB_VER}.tar.gz" | \
       tar -xz -C /tmp/ssdb --strip-components=1 \
    && cd /tmp/ssdb \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install PREFIX=/$DEST_BIN_DIR/bin/ssdb \
    && rm -rf /tmp/ssdb \
    && echo apk add --virtual .rundeps libstdc++ \
    && echo apk del .build-deps
}

_lualib() {
	# install luasocket
	echo ""
	echo -e "[\033[32mINSTALL\033[0m] luasocket"
	cd $BUILD_DIR
	tar zxf $SRC_DIR/build/install/luasocket-$LUASOCKET_VER.tar.gz
	cd luasocket-$LUASOCKET_VER
	mkdir -p /usr/local/openresty/luajit/lib/lua/5.1/socket/
	$SED_BIN "s#LUAPREFIX_linux?=/usr/local#LUAPREFIX_linux?=/usr/local/openresty/luajit#g" src/makefile
	$SED_BIN "s#LUAINC_linux_base?=/usr/include#LUAINC_linux_base?=/usr/local/openresty/luajit/include#g" src/makefile
	$SED_BIN "s#\$(LUAINC_linux_base)/lua/\$(LUAV)#\$(LUAINC_linux_base)/luajit-2.1#g" src/makefile

	make -j$(nproc) && make install-unix

	cp -f src/*.so /usr/local/openresty/luajit/lib/lua/5.1/socket/.

	# install luabson
	echo ""
	echo -e "[\033[32mINSTALL\033[0m] luabson"

	cd $BUILD_DIR
	tar zxf luabson-$LUABSON_VER.tar.gz
	cd lua-bson
	# if [ $OSTYPE == "MACOS" ]; then
	# 	$SED_BIN "s#-I/usr/local/include -L/usr/local/bin -llua53#-I/usr/local/openresty/luajit/include/luajit-2.1 -L/usr/local/openresty/luajit/lib -lluajit-5.1#g" Makefile
	# else
	$SED_BIN "s#-I/usr/local/include -L/usr/local/bin -llua53#-I/usr/local/openresty/luajit/include/luajit-2.1#g" Makefile
	# fi
	make linux

	# cp -f bson.so /usr/local/openresty/lualib
	cp -f bson.so /usr/local/openresty/luajit/lib/lua/5.1

	#install luapbc
	echo ""
	echo -e "[\033[32mINSTALL\033[0m] luapbc"

	cd $BUILD_DIR
	tar zxf luapbc-$LUAPBC_VER.tar.gz
	cd pbc
	make lib
	cd binding/lua
	# if [ $OSTYPE == "MACOS" ]; then
	# 	$SED_BIN "s#/usr/local/include#/usr/local/openresty/luajit/include/luajit-2.1 -L/usr/local/openresty/luajit/lib -lluajit-5.1#g" Makefile
	# else
	# 	$SED_BIN "s#/usr/local/include#/usr/local/openresty/luajit/include/luajit-2.1#g" Makefile
	$SED_BIN "s#/usr/local/include#/usr/local/openresty/luajit/include/luajit-2.1#g" Makefile
	# fi
	make

	# cp -f protobuf.so /usr/local/openresty/lualib
	# cp -f protobuf.lua /usr/local/openresty/lualib

	cp -f protobuf.so /usr/local/openresty/luajit/lib/lua/5.1
	cp -f protobuf.lua /usr/local/openresty/luajit/lib/lua/5.1

	# install luaprocess
	echo ""
	echo -e "[\033[32mINSTALL\033[0m] luaprocess"

	cd $BUILD_DIR
	tar zxf $SRC_DIR/build/install/lua-process-$LUAPROCESS_VER.tar.gz
	cd lua-process-$LUAPROCESS_VER
	cp Makefile Makefile_
	echo "PACKAGE=process" >Makefile
	echo "LIB_EXTENSION=so" >>Makefile
	echo "SRCDIR=src" >>Makefile
	echo "TMPLDIR=tmpl" >>Makefile
	echo "VARDIR=var" >>Makefile
	echo "CFLAGS=-Wall -fPIC -O2 -I/usr/include/luajit-2.1 -I/usr/local/openresty/luajit/include/luajit-2.1" >>Makefile
#	echo "CFLAGS=-Wall -fPIC -O2 -I/usr/include/luajit-2.1 -I_GBC_CORE_ROOT_/bin/openresty/luajit/include/luajit-2.1" >>Makefile
	echo "LDFLAGS=--shared -Wall -fPIC -O2 -L/usr/local/openresty/luajit/lib" >>Makefile
#	echo "LDFLAGS=--shared -Wall -fPIC -O2 -L_GBC_CORE_ROOT_/bin/openresty/luajit/lib" >>Makefile
	if [ $OSTYPE == "MACOS" ]; then
		echo "LIBS=-lluajit-5.1" >>Makefile
	fi
	echo "" >>Makefile
	cat Makefile_ >>Makefile
	rm Makefile_

	$SED_BIN "s#_GBC_CORE_ROOT_#$DEST_DIR#g" Makefile
	$SED_BIN "s#lua ./codegen.lua#/usr/local/openresty/luajit/bin/luajit ./codegen.lua#g" Makefile

	make

	# cp -f process.so /usr/local/openresty/lualib
	cp -f process.so /usr/local/openresty/luajit/lib/lua/5.1
	mkdir -p  /usr/local/openresty/site/lualib 
	#mkdir -p /usr/local/openresty/luajit/share/lua/5.1 /usr/local/openresty/luajit/lib/lua/5.1
	rsync -avz  /usr/local/openresty/luajit/lib/lua/5.1/* /usr/local/openresty/site/lualib/
	cd $DEST_BIN_DIR/bin
	ln -sf /usr/local/openresty .
}
# _keydb() {
# 	# ----
# 	#install redis
# 	echo ""
# 	echo -e "[\033[32mINSTALL\033[0m] redis"

# 	cd $BUILD_DIR
# 	rm -rf KeyDB
# 	#	if [ ! -d "KeyDB" ]; then
# 	git clone https://github.com/JohnSully/KeyDB.git
# 	#	fi
# 	cd KeyDB
# 	make distclean
# 	git reset --hard
# 	git pull
# 	#tar zxf $SRC_DIR/build/install/redis-$REDIS_VER.tar.gz
# 	#cd redis-$REDIS_VER
# 	$SRC_DIR/build/patch_redis_luajit.sh
# 	mkdir -p $DEST_BIN_DIR/keydb/bin

# 	make -j$(nproc)
# 	cp -f src/keydb-server $DEST_BIN_DIR/keydb/bin
# 	cp -f src/keydb-cli $DEST_BIN_DIR/keydb/bin
# 	cp -f src/keydb-sentinel $DEST_BIN_DIR/keydb/bin
# 	cp -f src/keydb-benchmark $DEST_BIN_DIR/keydb/bin
# 	cp -f src/keydb-check-aof $DEST_BIN_DIR/keydb/bin
# 	cp -f src/keydb-check-rdb $DEST_BIN_DIR/keydb/bin
# }
_redis() {
	# ----
	#install redis
	echo ""
	echo -e "[\033[32mINSTALL\033[0m] redis"

	cd $BUILD_DIR
	tar zxf $SRC_DIR/build/install/redis-$REDIS_VER.tar.gz
	cd redis-$REDIS_VER
	#$SRC_DIR/build/patch_redis_luajit.sh
	mkdir -p $DEST_BIN_DIR/bin/redis/bin

	make -j$(nproc)
	cp -f src/redis-server $DEST_BIN_DIR/bin/redis/bin
	cp -f src/redis-cli $DEST_BIN_DIR/bin/redis/bin
	cp -f src/redis-sentinel $DEST_BIN_DIR/bin/redis/bin
	cp -f src/redis-benchmark $DEST_BIN_DIR/bin/redis/bin
	cp -f src/redis-check-aof $DEST_BIN_DIR/bin/redis/bin
}
_beanstalkd() {
	# ----
	# install beanstalkd
	echo ""
	echo -e "[\033[32mINSTALL\033[0m] beanstalkd"

	cd $BUILD_DIR
	tar zxf $SRC_DIR/build/install/beanstalkd-$BEANSTALKD_VER.tar.gz
	cd beanstalkd-$BEANSTALKD_VER
	mkdir -p $DEST_BIN_DIR/bin/beanstalkd/bin

	make -j$(nproc)
	cp -f beanstalkd $DEST_BIN_DIR/bin/beanstalkd/bin
}
_gdnsd(){
GDNS_VER="3.8.0"
GDNS_OPT="--prefix=$DEST_BIN_DIR/bin/gdnsd"
GDNS_BUILD_DEPENDENCY="perl perl-libwww ragel libev-dev autoconf automake libtool userspace-rcu-dev libcap-dev libmaxminddb-dev perl-test-harness perl-test-harness-utils libsodium-dev"

apk update \
&& apk add gcc g++ make patch file openssl ${GDNS_BUILD_DEPENDENCY} \
&& cd /tmp \
&& wget https://github.com/gdnsd/gdnsd/releases/download/v${GDNS_VER}/gdnsd-${GDNS_VER}.tar.xz \
&& tar xJf gdnsd-${GDNS_VER}.tar.xz \
&& cd gdnsd-${GDNS_VER} \
&& autoreconf -vif \
&& ./configure ${GDNS_OPT} \
&& make \
&& make install \
&& rm -rf /tmp/gdnsd*
}
_prometheus(){
    PROME_VER=2.41.0
    cd /tmp
    wget https://github.com/prometheus/prometheus/releases/download/v${PROME_VER}/prometheus-${PROME_VER}.linux-amd64.tar.gz
    tar -xvzf prometheus-${PROME_VER}.linux-amd64.tar.gz
    mv prometheus-${PROME_VER} $DEST_BIN_DIR/bin/prometheus
    rm /tmp/prometheus-*
}
_loki(){
    mkdir -p $DEST_BIN_DIR/bin/loki
    cd /tmp
    LOKI_VER=2.7.1
    wget https://github.com/grafana/loki/releases/download/v${LOKI_VER}/loki-linux-amd64.zip
    unzip loki-linux-amd64.zip
    mv loki-linux-amd64  $DEST_BIN_DIR/bin/loki/loki
    wget "https://github.com/grafana/loki/releases/download/v${LOKI_VER}/promtail-linux-amd64.zip"
    unzip promtail-linux-amd64.zip
    mv promtail-linux-amd64 $DEST_BIN_DIR/bin/loki/promtail
    chmod +x $DEST_BIN_DIR/bin/loki/*
}
# _tools() {
# 	mkdir -p $DEST_BIN_DIR/bin
# 	curl -o $DEST_BIN_DIR/bin/jemplate https://raw.githubusercontent.com/ingydotnet/jemplate/master/jemplate
# 	curl -o $DEST_BIN_DIR/bin/lemplate https://raw.githubusercontent.com/openresty/lemplate/master/lemplate
# 	chmod +x $DEST_BIN_DIR/bin/jemplate $DEST_BIN_DIR/bin/lemplate

# 	echo "DONE!"
# 	echo ""
# }
if [ $# -gt 2 ];then shift 2; $@;exit 0;fi

_env
_env_gbc
_lualib
_ssdb
_redis
_beanstalkd
#_prometheus
#_gdnsd
#_loki

