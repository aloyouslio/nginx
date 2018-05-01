#!/bin/bash
yum -y install gcc gcc-c++ make patch libxml2 libxml2-devel zlib zlib-devel pcre pcre-devel openssl openssl-devel autoconf libtool automake GeoIP GeoIP-devel

mkdir -p ~/nginx
cd ~/nginx
wget http://nginx.org/download/nginx-1.12.1.tar.gz
tar xfz nginx-1.12.1.tar.gz

git clone https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng.git sticky
git clone https://github.com/yaoweibin/nginx_upstream_check_module.git check
git clone git://github.com/AirisX/nginx_cookie_flag_module.git secure

cd nginx-1.12.1
patch -p1 < ../check/check_1.12.1+.patch
cd ../sticky
patch -p0 < ../check/nginx-sticky-module.patch

cd ../nginx-1.12.1
./configure --user=nginx --group=nginx --with-debug --with-pcre-jit --with-pcre --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_ssl_module \
--add-module=../sticky \
--with-http_geoip_module \
--add-module=../check \
--add-module=../secure \
--with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic'
make
make install

cat > /usr/lib/systemd/system/nginx.service <<  EOF
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target
[Service]
Type=forking
PIDFile=/run/nginx.pid
# Nginx will fail to start if /run/nginx.pid already exists but has the wrong
# SELinux context. This might happen when running `nginx -t` from the cmdline.
# https://bugzilla.redhat.com/show_bug.cgi?id=1268621
ExecStartPre=/usr/bin/rm -f /run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF

printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" > /etc/systemd/system/nginx.service.d/override.conf
systemctl daemon-reload
systemctl restart nginx
systemctl status nginx

sudo systemctl start nginx.service && sudo systemctl enable nginx.service
sudo systemctl status nginx.service
ps aux | grep nginx
