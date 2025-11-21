#!/bin/bash
set -e

# 当前工作目录。拼接绝对路径的时候需要用到这个值。
WORKDIR=$(pwd)

# 如果存在旧的目录和文件，就清理掉
rm -rf *.tar.gz \
    openssl-1.1.1w \
    zlib-1.3.1 \
    expat-2.6.2 \
    libiconv-1.17 \
    pcre2-10.43 \
    curl-8.0.1 \
    gettext-0.22 \
    git-2.45.2 \
    ohos-sdk \
    deps \
    git-2.45.2-ohos-arm64

# 准备 ohos-sdk
mkdir ohos-sdk
curl -L -O https://repo.huaweicloud.com/openharmony/os/6.0-Release/ohos-sdk-windows_linux-public.tar.gz
tar -zxf ohos-sdk-windows_linux-public.tar.gz -C ohos-sdk
cd ohos-sdk/linux
unzip -q native-*.zip
cd ../..

# 设置交叉编译所需的环境变量
export OHOS_SDK=${WORKDIR}/ohos-sdk/linux
export AS=${OHOS_SDK}/native/llvm/bin/llvm-as
export CC="${OHOS_SDK}/native/llvm/bin/clang --target=aarch64-linux-ohos"
export CXX="${OHOS_SDK}/native/llvm/bin/clang++ --target=aarch64-linux-ohos"
export LD=${OHOS_SDK}/native/llvm/bin/ld.lld
export STRIP=${OHOS_SDK}/native/llvm/bin/llvm-strip
export RANLIB=${OHOS_SDK}/native/llvm/bin/llvm-ranlib
export OBJDUMP=${OHOS_SDK}/native/llvm/bin/llvm-objdump
export OBJCOPY=${OHOS_SDK}/native/llvm/bin/llvm-objcopy
export NM=${OHOS_SDK}/native/llvm/bin/llvm-nm
export AR=${OHOS_SDK}/native/llvm/bin/llvm-ar
export CFLAGS="-D__MUSL__=1"
export CXXFLAGS="-D__MUSL__=1"

# 编译 openssl
curl -L -O https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1w/openssl-1.1.1w.tar.gz
tar -zxf openssl-1.1.1w.tar.gz
cd openssl-1.1.1w
./Configure --prefix=${WORKDIR}/deps linux-aarch64 no-shared
make -j$(nproc)
make install
cd ..

# 编译 zlib
curl -L -O https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
tar -zxf zlib-1.3.1.tar.gz
cd zlib-1.3.1
./configure --prefix=${WORKDIR}/deps --static
make -j$(nproc)
make install
cd ..

# 编译 expat
curl -L -O https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.gz
tar -zxf expat-2.6.2.tar.gz
cd expat-2.6.2
./configure \
    --prefix=${WORKDIR}/deps \
    --host=aarch64-linux \
    --without-xmlwf \
    --without-examples \
    --without-tests \
    --without-docbook \
    --disable-shared
make -j$(nproc)
make install
cd ..

# 编译 libiconv
curl -L -O http://mirrors.ustc.edu.cn/gnu/libiconv/libiconv-1.17.tar.gz
tar -zxf libiconv-1.17.tar.gz
cd libiconv-1.17
./configure --prefix=${WORKDIR}/deps --host=aarch64-linux  --disable-shared
make -j$(nproc)
make install
cd ..

# 编译 pcre2
curl -L -O https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.gz
tar -zxf pcre2-10.43.tar.gz
cd pcre2-10.43
./configure --prefix=${WORKDIR}/deps --host=aarch64-linux --disable-shared
make -j$(nproc)
make install
cd ..

# 编译 curl
curl -L -O https://curl.se/download/curl-8.0.1.tar.gz
tar -zxf curl-8.0.1.tar.gz
cd curl-8.0.1
./configure \
    --prefix=${WORKDIR}/deps \
    --host=aarch64-linux \
    --with-openssl=${WORKDIR}/deps \
    --with-ca-bundle=/etc/ssl/certs/cacert.pem \
    --with-ca-path=/etc/ssl/certs \
    --disable-shared \
    CPPFLAGS="-D_GNU_SOURCE"
make -j$(nproc)
make install
cd ..

# 编译 gettext
curl -L -O http://mirrors.ustc.edu.cn/gnu/gettext/gettext-0.22.tar.gz
tar -zxf gettext-0.22.tar.gz
cd gettext-0.22
./configure --prefix=${WORKDIR}/deps --host=aarch64-linux --disable-shared 
make -j$(nproc)
make install
cd ..

# 编译 git
curl -L https://github.com/git/git/archive/refs/tags/v2.45.2.tar.gz -o git-2.45.2.tar.gz
tar -zxf git-2.45.2.tar.gz
cd git-2.45.2
patch -p1 < ../0001-let-git-portable.patch
make configure
./configure \
    --prefix=${WORKDIR}/git-2.45.2-ohos-arm64 \
    --host=aarch64-linux \
    --with-expat=${WORKDIR}/deps \
    --with-libpcre2=${WORKDIR}/deps \
    --with-openssl=${WORKDIR}/deps \
    --with-iconv=${WORKDIR}/deps \
    --with-curl=${WORKDIR}/deps \
    --with-zlib=${WORKDIR}/deps \
    --with-editor=false \
    --with-pager=more \
    --with-tcltk=no \
    --disable-pthreads \
    ac_cv_iconv_omits_bom=yes \
    ac_cv_fread_reads_directories=yes \
    ac_cv_snprintf_returns_bogus=no \
    ac_cv_lib_curl_curl_global_init=yes \
    ac_cv_prog_CURL_CONFIG=${WORKDIR}/deps/bin/curl-config \
    CPPFLAGS="-I${WORKDIR}/deps/include -DRUNTIME_PREFIX" \
    LDFLAGS="-L${WORKDIR}/deps/lib"
make -j$(nproc) RUNTIME_PREFIX=1
make install
cd ..

# 履行开源义务，把使用的开源软件的 license 全部聚合起来放到制品中
git_license=$(cat git-2.45.2/COPYING; echo)
openssl_license=$(cat openssl-1.1.1w/LICENSE; echo)
openssl_authors=$(cat openssl-1.1.1w/AUTHORS; echo)
zlib_license=$(cat zlib-1.3.1/LICENSE; echo)
expat_license=$(cat expat-2.6.2/COPYING; echo)
expat_authors=$(cat expat-2.6.2/AUTHORS; echo)
libiconv_license=$(cat libiconv-1.17/COPYING; echo)
libiconv_authors=$(cat libiconv-1.17/AUTHORS; echo)
pcre2_license=$(cat pcre2-10.43/LICENCE; echo)
pcre2_authors=$(cat pcre2-10.43/AUTHORS; echo)
curl_license=$(cat curl-8.0.1/COPYING; echo)
gettext_license=$(cat gettext-0.22/COPYING; echo)
gettext_authors=$(cat gettext-0.22/AUTHORS; echo)
printf '%s\n' "$(cat <<EOF
This document describes the licenses of all software distributed with the
bundled application.
==========================================================================

git
=============
$git_license

openssl
=============
==license==
$openssl_license
==authors==
$openssl_authors

zlib
=============
$zlib_license

expat
=============
==license==
$expat_license
==authors==
$expat_authors

libiconv
=============
==license==
$libiconv_license
==authors==
$libiconv_authors

pcre2
=============
==license==
$pcre2_license
==authors==
$pcre2_authors

curl
=============
$curl_license

gettext
=============
==license==
$gettext_license
==authors==
$gettext_authors
EOF
)" > git-2.45.2-ohos-arm64/licenses.txt

# 打包最终产物
tar -zcf git-2.45.2-ohos-arm64.tar.gz git-2.45.2-ohos-arm64
