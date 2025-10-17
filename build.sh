#!/bin/bash
set -e

# Setup ohos-sdk
query_component() {
  component=$1
  curl -fsSL 'https://ci.openharmony.cn/api/daily_build/build/list/component' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: application/json' \
    --data-raw '{"projectName":"openharmony","branch":"master","pageNum":1,"pageSize":10,"deviceLevel":"","component":"'${component}'","type":1,"startTime":"2025080100000000","endTime":"20990101235959","sortType":"","sortField":"","hardwareBoard":"","buildStatus":"success","buildFailReason":"","withDomain":1}'
}
sdk_download_url=$(query_component "ohos-sdk-public" | jq -r ".data.list.dataList[0].obsPath")
curl $sdk_download_url -o ohos-sdk-public.tar.gz
mkdir -p /opt/ohos-sdk
tar -zxf ohos-sdk-public.tar.gz -C /opt/ohos-sdk
cd /opt/ohos-sdk/linux
unzip -q native-*.zip
unzip -q toolchains-*.zip
cd - >/dev/null

# setup env
export OHOS_SDK=/opt/ohos-sdk/linux
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
export CFLAGS="-fPIC -D__MUSL__=1"
export CXXFLAGS="-fPIC -D__MUSL__=1"

# Build openssl
curl -L -O https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1w/openssl-1.1.1w.tar.gz
tar -zxf openssl-1.1.1w.tar.gz
cd openssl-1.1.1w/
./Configure --prefix=/opt/deps linux-aarch64 no-shared
make -j$(nproc)
make install
cd ..

# Build zlib
curl -L -O https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz
tar -zxf zlib-1.3.1.tar.gz
cd zlib-1.3.1
./configure --prefix=/opt/deps --static
make -j$(nproc)
make install
cd ..

# Build expat
curl -L -O https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.gz
tar -zxf expat-2.6.2.tar.gz
cd expat-2.6.2/
./configure \
    --prefix=/opt/deps \
    --host=aarch64-linux \
    --without-xmlwf \
    --without-examples \
    --without-tests \
    --without-docbook \
    --disable-shared
make -j$(nproc)
make install
cd ..

# Build libiconv
curl -L -O http://mirrors.ustc.edu.cn/gnu/libiconv/libiconv-1.17.tar.gz
tar -zxf libiconv-1.17.tar.gz
cd libiconv-1.17
./configure --prefix=/opt/deps --host=aarch64-linux  --disable-shared
make -j$(nproc)
make install
cd ..

# Build pcre2
curl -L -O https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.gz
tar -zxf pcre2-10.43.tar.gz
cd pcre2-10.43/
./configure --prefix=/opt/deps --host=aarch64-linux --disable-shared
make -j$(nproc)
make install
cd ..

# Build curl
curl -L -O https://curl.se/download/curl-8.0.1.tar.gz
tar -zxf curl-8.0.1.tar.gz
cd curl-8.0.1/
./configure \
    --prefix=/opt/deps \
    --host=aarch64-linux \
    --with-openssl=/opt/deps \
    --with-ca-bundle=/etc/ssl/certs/cacert.pem \
    --with-ca-path=/etc/ssl/certs \
    --disable-shared \
    CFLAGS="-Wno-int-conversion $CFLAGS"
make -j$(nproc)
make install
cd ..

# Build gettext
curl -L -O http://mirrors.ustc.edu.cn/gnu/gettext/gettext-0.22.tar.gz
tar -zxf gettext-0.22.tar.gz
cd gettext-0.22/
./configure \
    --prefix=/opt/deps \
    --host=aarch64-linux \
    --disable-shared \
    CFLAGS="-Wno-int-conversion $CFLAGS"
make -j$(nproc)
make install
cd ..

# Build git
curl -L https://github.com/git/git/archive/refs/tags/v2.45.2.tar.gz -o git-2.45.2.tar.gz
tar -zxf git-2.45.2.tar.gz
cd git-2.45.2
make configure
./configure \
    --prefix=/opt/git-2.45.2-ohos-arm64 \
    --host=aarch64-linux \
    --with-expat=/opt/deps \
    --with-libpcre2=/opt/deps \
    --with-openssl=/opt/deps \
    --with-iconv=/opt/deps \
    --with-curl=/opt/deps \
    --with-zlib=/opt/deps \
    --with-editor=false \
    --with-pager=more \
    --with-tcltk=no \
    --disable-pthreads \
    ac_cv_iconv_omits_bom=yes \
    ac_cv_fread_reads_directories=yes \
    ac_cv_snprintf_returns_bogus=no \
    ac_cv_lib_curl_curl_global_init=yes \
    ac_cv_prog_CURL_CONFIG=/opt/deps/bin/curl-config \
    CFLAGS="-I/opt/deps/include" \
    CPPFLAGS="-I/opt/deps/include" \
    LDFLAGS="-L/opt/deps/lib"
make -j$(nproc)
make install
cp COPYING /opt/git-2.45.2-ohos-arm64/
cd ..

# Codesign
elf_files=$(find /opt/git-2.45.2-ohos-arm64/libexec/git-core -type f -print0 \
    | xargs -0 -n256 file -N \
    | awk -F: '$2 ~ /ELF/ {print $1}')
elf_files_unique=$(echo "$elf_files" \
    | xargs -n1 stat -c '%i %n' 2>/dev/null \
    | sort -k1,1 -u \
    | cut -d' ' -f2-)
echo "$elf_files_unique" | xargs -I {} /opt/ohos-sdk/linux/toolchains/lib/binary-sign-tool sign -inFile {} -outFile {} -selfSign 1

cd /opt
tar -zcf git-2.45.2-ohos-arm64.tar.gz git-2.45.2-ohos-arm64
