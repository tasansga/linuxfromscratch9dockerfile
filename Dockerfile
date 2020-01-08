FROM centos:8 AS buildenv

RUN yum -y --allowerasing install \
        bash \
        binutils \
        bison \
        bzip2 \
        coreutils \
        diffutils \
        findutils \
        gawk \
        gcc \
        glibc \
        grep \
        gzip \
        m4 \
        make \
        patch \
        perl \
        python3 \
        wget \
        sed \
        tar \
        info \
        gettext \
        xz \
        gcc-c++ \
        rsync

ENV LFS /lfs

RUN mkdir -p /lfs/tools /lfs/sources /lfs/scripts && \
    chmod a+wt /lfs/sources && \
    ln -s $LFS/tools / && \
    groupadd lfs && \
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs && \
    chown lfs $LFS/sources && \
    chown lfs $LFS/tools

COPY scripts/* /lfs/scripts/

RUN ln -s /lfs/scripts/yacc /usr/bin/ && \
    /lfs/scripts/version-check.sh

USER lfs

# uname -m
ENV UNAME x86_64
ENV LC_ALL POSIX
ENV LFS_TGT "${UNAME}-lfs-linux-gnu"
ENV PATH /tools/bin:/bin:/usr/bin

COPY sources /lfs/sources/

RUN cd /lfs/sources && \
    wget -nv -i wget-list

ENV MAKEFLAGS='-j 3'

WORKDIR /lfs/sources

RUN tar xf binutils-2.33.1.tar.xz && \
    cd binutils-2.33.1 && \
    mkdir build && \
    cd build && \
    ../configure --prefix=/tools        \
             --with-sysroot=$LFS        \
             --with-lib-path=/tools/lib \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror && \
    make && \
    mkdir -v /tools/lib && \
    ln -sv lib /tools/lib64 && \
    make install && \
    cd /lfs/sources && \
    rm -Rf binutils-2.33.1

RUN tar xf gcc-9.2.0.tar.xz && \
    cd gcc-9.2.0 && \
    tar -xf ../mpfr-4.0.2.tar.xz && \
    mv -v mpfr-4.0.2 mpfr && \
    tar -xf ../gmp-6.1.2.tar.xz && \
    mv -v gmp-6.1.2 gmp && \
    tar -xf ../mpc-1.1.0.tar.gz && \
    mv -v mpc-1.1.0 mpc && \
    cp /lfs/scripts/gcc_prepare.sh . && \
    ./gcc_prepare.sh && \
    mkdir build && \
    cd build && \
    ../configure                                       \
        --target=$LFS_TGT                              \
        --prefix=/tools                                \
        --with-glibc-version=2.11                      \
        --with-sysroot=$LFS                            \
        --with-newlib                                  \
        --without-headers                              \
        --with-local-prefix=/tools                     \
        --with-native-system-header-dir=/tools/include \
        --disable-nls                                  \
        --disable-shared                               \
        --disable-multilib                             \
        --disable-decimal-float                        \
        --disable-threads                              \
        --disable-libatomic                            \
        --disable-libgomp                              \
        --disable-libquadmath                          \
        --disable-libssp                               \
        --disable-libvtv                               \
        --disable-libstdcxx                            \
        --enable-languages=c,c++ && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf gcc-9.2.0

RUN tar xf linux-5.4.2.tar.xz && \
    cd linux-5.4.2 && \
    make mrproper && \
    make INSTALL_HDR_PATH=dest headers_install && \
    cp -rv dest/include/* /tools/include && \
    cd /lfs/sources && \
    rm -Rf linux-5.4.2

RUN tar xf glibc-2.30.tar.xz && \
    cd glibc-2.30 && \
    mkdir -v build && \
    cd build && \
    ../configure                         \
      --prefix=/tools                    \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=/tools/include && \
    make -j1 && \
    make install && \
    echo 'int main(){}' > dummy.c && \
    $LFS_TGT-gcc dummy.c && \
    readelf -l a.out | grep ': /tools' && \
    cd /lfs/sources && \
    rm -Rf glibc-2.30

RUN tar xf gcc-9.2.0.tar.xz && \
    cd gcc-9.2.0 && \
    mkdir -v build && \
    cd build && \
    ../libstdc++-v3/configure           \
        --host=$LFS_TGT                 \
        --prefix=/tools                 \
        --disable-multilib              \
        --disable-nls                   \
        --disable-libstdcxx-threads     \
        --disable-libstdcxx-pch         \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/9.2.0 && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -rf gcc-9.2.0

RUN tar xf binutils-2.33.1.tar.xz && \
    cd binutils-2.33.1 && \
    mkdir build && \
    cd build && \
    export CC=$LFS_TGT-gcc && \
    export AR=$LFS_TGT-ar && \
    export RANLIB=$LFS_TGT-ranlib && \
    ../configure                   \
        --prefix=/tools            \
        --disable-nls              \
        --disable-werror           \
        --with-lib-path=/tools/lib \
        --with-sysroot && \
    make && \
    make install && \
    make -C ld clean && \
    make -C ld LIB_PATH=/usr/lib:/lib && \
    cp -v ld/ld-new /tools/bin && \
    cd /lfs/sources && \
    rm -Rf binutils-2.33.1

RUN tar xf gcc-9.2.0.tar.xz && \
    cd gcc-9.2.0 && \
    tar -xf ../mpfr-4.0.2.tar.xz && \
    mv -v mpfr-4.0.2 mpfr && \
    tar -xf ../gmp-6.1.2.tar.xz && \
    mv -v gmp-6.1.2 gmp && \
    tar -xf ../mpc-1.1.0.tar.gz && \
    mv -v mpc-1.1.0 mpc && \
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
        $(dirname $($LFS_TGT-gcc -print-libgcc-file-name))/include-fixed/limits.h && \
    cp /lfs/scripts/gcc_prepare.sh . && \
    ./gcc_prepare.sh && \
    mkdir build && \
    cd build && \
    export CC=$LFS_TGT-gcc && \
    export CXX=$LFS_TGT-g++ && \
    export AR=$LFS_TGT-ar && \
    export RANLIB=$LFS_TGT-ranlib && \
    ../configure                                       \
        --prefix=/tools                                \
        --with-local-prefix=/tools                     \
        --with-native-system-header-dir=/tools/include \
        --enable-languages=c,c++                       \
        --disable-libstdcxx-pch                        \
        --disable-multilib                             \
        --disable-bootstrap                            \
        --disable-libgomp && \
    make && \
    make install && \
    ln -sv gcc /tools/bin/cc && \
    echo 'int main(){}' > dummy.c && \
    cc dummy.c && \
    readelf -l a.out | grep ': /tools' && \
    cd /lfs/sources && \
    rm -Rf gcc-9.2.0

RUN tar xf tcl8.6.10-src.tar.gz && \
    cd tcl8.6.10 && \
    cd unix && \
    ./configure --prefix=/tools && \
    make && \
    export TZ=UTC && \
    make test && \
    make install && \
    chmod -v u+w /tools/lib/libtcl8.6.so && \
    make install-private-headers && \
    ln -sv tclsh8.6 /tools/bin/tclsh && \
    cd /lfs/sources && \
    rm -Rf tcl-8.6.10

RUN tar xf expect5.45.4.tar.gz && \
    cd expect5.45.4 && \
    cp -v configure{,.orig} && \
    sed 's:/usr/local/bin:/bin:' configure.orig > configure && \
    ./configure --prefix=/tools       \
        --with-tcl=/tools/lib \
        --with-tclinclude=/tools/include && \
    make && \
    make test && \
    make SCRIPTS="" install && \
    cd /lfs/sources && \
    rm -Rf expect5.45.4

RUN tar xf dejagnu-1.6.2.tar.gz && \
    cd dejagnu-1.6.2 && \
    ./configure --prefix=/tools && \
    make install && \
    make check && \
    cd /lfs/sources && \
    rm -Rf dejagnu-1.6.2

RUN tar xf m4-1.4.18.tar.xz && \
    cd m4-1.4.18 && \
    sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c && \
    echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf m4-1.4.18

RUN tar xf ncurses-6.1.tar.gz && \
    cd ncurses-6.1 && \
    sed -i s/mawk// configure && \
    ./configure --prefix=/tools \
        --with-shared   \
        --without-debug \
        --without-ada   \
        --enable-widec  \
        --enable-overwrite && \
    make && \
    make install && \
    ln -s libncursesw.so /tools/lib/libncurses.so && \
    cd /lfs/sources && \
    rm -Rf ncurses-6.1

RUN tar xf bash-5.0.tar.gz && \
    cd bash-5.0 && \
    ./configure --prefix=/tools --without-bash-malloc && \
    make && \
    make install && \
    ln -sv bash /tools/bin/sh && \
    cd /lfs/sources && \
    rm -Rf bash-5.0

ENV MAKEFLAGS='-j 1'

RUN tar xf bison-3.4.2.tar.xz && \
    cd bison-3.4.2 && \
    ./configure --prefix=/tools && \
    make -j1 && \
    make install && \
    cd /lfs/sources && \
    rm -Rf bison-3.4.2

ENV MAKEFLAGS='-j 3'

RUN tar xf bzip2-1.0.8.tar.gz && \
    cd bzip2-1.0.8 && \
    make && \
    make PREFIX=/tools install && \
    cd /lfs/sources && \
    rm -Rf bzip2-1.0.8

RUN tar xf coreutils-8.31.tar.xz && \
    cd coreutils-8.31 && \
    ./configure --prefix=/tools --enable-install-program=hostname && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf coreutils-8.31

RUN tar xf diffutils-3.7.tar.xz && \
    cd diffutils-3.7 && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf diffutils-3.7

RUN tar xf file-5.37.tar.gz && \
    cd file-5.37 && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf file-5.37

RUN tar xf findutils-4.7.0.tar.xz && \
    cd findutils-4.7.0 && \
    sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c && \
    sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c && \
    echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf findutils-4.7.0

RUN tar xf gawk-5.0.1.tar.xz && \
    cd gawk-5.0.1 && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf gawk-5.0.1

RUN tar xf gettext-0.20.1.tar.xz && \
    cd gettext-0.20.1 && \
    ./configure --disable-shared && \
    make && \
    cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /tools/bin && \
    cd /lfs/sources && \
    rm -Rf gettext-0.20.1

RUN tar xf grep-3.3.tar.xz && \
    cd grep-3.3 && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf grep-3.3

RUN tar xf gzip-1.10.tar.xz && \
    cd gzip-1.10 && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf gzip-1.10

RUN tar xf make-4.2.1.tar.gz && \
    cd make-4.2.1 && \
    sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c && \
    ./configure --prefix=/tools --without-guile && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf make-4.2.1

RUN tar xf patch-2.7.6.tar.xz && \
    cd patch-2.7.6 && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf patch-2.7.6

RUN tar xf perl-5.30.1.tar.xz && \
    cd perl-5.30.1 && \
    sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth && \
    make && \
    cp -v perl cpan/podlators/scripts/pod2man /tools/bin && \
    mkdir -pv /tools/lib/perl5/5.30.1 && \
    cp -Rv lib/* /tools/lib/perl5/5.30.1 && \
    cd /lfs/sources && \
    rm -Rf perl-5.30.1

RUN tar xf Python-3.8.0.tar.xz && \
    cd Python-3.8.0 && \
    sed -i '/def add_multiarch_paths/a \        return' setup.py && \
    ./configure --prefix=/tools --without-ensurepip && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf Python-3.8.0

RUN tar xf sed-4.7.tar.xz && \
    cd sed-4.7 && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf sed-4.7

RUN tar xf tar-1.32.tar.xz && \
    cd tar-1.32 && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf tar-1.32

RUN tar xf texinfo-6.7.tar.xz && \
    cd texinfo-6.7 && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf texinfo-6.7

RUN tar xf xz-5.2.4.tar.xz && \
    cd xz-5.2.4 && \
    ./configure --prefix=/tools && \
    make && \
    make install && \
    cd /lfs/sources && \
    rm -Rf xz-5.2.4

RUN strip --strip-debug /tools/lib/* || exit 0 && \
    /usr/bin/strip --strip-unneeded /tools/{,s}bin/* && \
    rm -rf /tools/{,share}/{info,man,doc} && \
    find /tools/{lib,libexec} -name \*.la -delete

USER root

RUN chown -R root:root $LFS/tools

RUN mkdir -pv $LFS/{dev,proc,sys,run,dev/pts} && \
    mknod -m 600 $LFS/dev/console c 5 1 && \
    mknod -m 666 $LFS/dev/null c 1 3 && \
    mkdir -p $LFS/bin && \
    ln -vs /tools/bin/bash $LFS/bin/sh


FROM scratch AS chrootenv

COPY --from=buildenv /lfs /

ENV PATH /bin:/usr/bin:/sbin:/usr/sbin:/tools/bin
ENV PS1 '(lfs chroot) \u:\w\$ '

COPY files/etc/passwd /etc/passwd
COPY files/etc/group /etc/group

RUN chmod -v 644  /etc/passwd && \
    chmod -v 644  /etc/group && \
    chown -R root.root /sources && \
    mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt} && \
    mkdir -pv /{media/{floppy,cdrom},sbin,srv,var} && \
    install -dv -m 0750 /root && \
    install -dv -m 1777 /tmp /var/tmp && \
    mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src} && \
    mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man} && \
    mkdir -v  /usr/{,local/}share/{misc,terminfo,zoneinfo} && \
    mkdir -v  /usr/libexec && \
    mkdir -pv /usr/{,local/}share/man/man{1..8} && \
    mkdir -v  /usr/lib/pkgconfig && \
    bash -c 'case $(uname -m) in x86_64) mkdir -v /lib64 ;; esac' && \
    mkdir -v /var/{log,mail,spool} && \
    ln -sv /run /var/run && \
    ln -sv /run/lock /var/lock && \
    mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local} && \
    ln -sv /tools/bin/{bash,cat,chmod,dd,echo,ln,mkdir,pwd,rm,stty,touch} /bin && \
    ln -sv /tools/bin/{env,install,perl,printf}         /usr/bin && \
    ln -sv /tools/lib/libgcc_s.so{,.1}                  /usr/lib && \
    ln -sv /tools/lib/libstdc++.{a,so{,.6}}             /usr/lib && \
    rm -f /bin/sh && \
    ln -sv bash /bin/sh && \
    touch /var/log/{btmp,lastlog,faillog,wtmp} && \
    chgrp -v utmp /var/log/lastlog && \
    chmod -v 664  /var/log/lastlog && \
    chmod -v 600  /var/log/btmp && \
    mv -v /sources/* /usr/src/ && \
    rmdir -v /sources

COPY scripts /usr/src/scripts/

WORKDIR /usr/src

RUN set +o hashall && \
    tar xf linux-5.4.2.tar.xz && \
    cd linux-5.4.2 && \
    make mrproper && \
    make headers && \
    find usr/include -name '.*' -delete && \
    rm usr/include/Makefile && \
    cp -rv usr/include/* /usr/include && \
    cd /usr/src && \
    rm -Rf linux-5.4.2

RUN set +o hashall && \
    tar xf man-pages-5.04.tar.xz && \
    cd man-pages-5.04 && \
    make install && \
    cd /usr/src && \
    rm -Rf man-pages-5.04

RUN set +o hashall && \
    tar xf glibc-2.30.tar.xz && \
    cd glibc-2.30 && \
    patch -Np1 -i ../glibc-2.30-fhs-1.patch && \
    sed -i '/asm.socket.h/a# include <linux/sockios.h>' \
        sysdeps/unix/sysv/linux/bits/socket.h && \
    /usr/src/scripts/glibc_symlink.sh && \
    export CC="gcc -ffile-prefix-map=/tools=/usr" && \
    mkdir -v build && \
    cd build && \
    ../configure --prefix=/usr                 \
        --disable-werror                       \
        --enable-kernel=3.2                    \
        --enable-stack-protector=strong        \
        --with-headers=/usr/include            \
        libc_cv_slibdir=/lib && \
    make && \
    bash -c 'case $(uname -m) in i386) ln -sfnv $PWD/elf/ld-linux.so.2 /lib ;; x86_64) ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib ;; esac' && \
    touch /etc/ld.so.conf && \
    make check || true && \
    sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile && \
    make install && \
    cp -v ../nscd/nscd.conf /etc/nscd.conf && \
    mkdir -pv /var/cache/nscd && \
    mkdir -pv /usr/lib/locale && \
    localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true && \
    localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8 && \
    localedef -i de_DE -f ISO-8859-1 de_DE && \
    localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro && \
    localedef -i de_DE -f UTF-8 de_DE.UTF-8 && \
    localedef -i el_GR -f ISO-8859-7 el_GR && \
    localedef -i en_GB -f UTF-8 en_GB.UTF-8 && \
    localedef -i en_HK -f ISO-8859-1 en_HK && \
    localedef -i en_PH -f ISO-8859-1 en_PH && \
    localedef -i en_US -f ISO-8859-1 en_US && \
    localedef -i en_US -f UTF-8 en_US.UTF-8 && \
    localedef -i es_MX -f ISO-8859-1 es_MX && \
    localedef -i fa_IR -f UTF-8 fa_IR && \
    localedef -i fr_FR -f ISO-8859-1 fr_FR && \
    localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro && \
    localedef -i fr_FR -f UTF-8 fr_FR.UTF-8 && \
    localedef -i it_IT -f ISO-8859-1 it_IT && \
    localedef -i it_IT -f UTF-8 it_IT.UTF-8 && \
    localedef -i ja_JP -f EUC-JP ja_JP && \
    localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true && \
    localedef -i ja_JP -f UTF-8 ja_JP.UTF-8 && \
    localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R && \
    localedef -i ru_RU -f UTF-8 ru_RU.UTF-8 && \
    localedef -i tr_TR -f UTF-8 tr_TR.UTF-8 && \
    localedef -i zh_CN -f GB18030 zh_CN.GB18030 && \
    localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS && \
    /usr/src/scripts/glibc_create_timezones.sh && \
    echo -e "/usr/local/lib\n\n" > /etc/ld.so.conf && \
    cd /usr/src && \
    rm -Rf glibc-2.30

COPY files/etc/nsswitch.conf /etc/

# TODO verify output LFS-9.0/chapter06/adjusting.html
RUN set +o hashall && \
    mv -v /tools/bin/{ld,ld-old} && \
    mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old} && \
    mv -v /tools/bin/{ld-new,ld} && \
    ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld && \
    gcc -dumpspecs | sed -e 's@/tools@@g'                   \
        -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
        -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
        `dirname $(gcc --print-libgcc-file-name)`/specs && \
    echo 'int main(){}' > dummy.c && \
    cc dummy.c -v -Wl,--verbose &> dummy.log && \
    readelf -l a.out | grep ': /lib' && \
    grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log && \
    grep -B1 '^ /usr/include' dummy.log && \
    grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g' && \
    grep "/lib.*/libc.so.6 " dummy.log && \
    grep found dummy.log && \
    rm -v dummy.c a.out dummy.log

RUN set +o hashall && \
    tar xf zlib-1.2.11.tar.xz && \
    cd zlib-1.2.11 && \
    ./configure --prefix=/usr && \
    make && \
    make check && \
    make install && \
    cd /usr/src && \
    rm -Rf zlib-1.2.11 && \
    mv -v /usr/lib/libz.so.* /lib && \
    ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so

RUN set +o hashall && \
    tar xf file-5.37.tar.gz && \
    cd file-5.37 && \
    ./configure --prefix=/usr && \
    make && \
    make check && \
    make install && \
    cd /usr/src && \
    rm -Rf file-5.37

RUN set +o hashall && \
    tar xf readline-8.0.tar.gz && \
    cd readline-8.0 && \
    sed -i '/MV.*old/d' Makefile.in && \
    sed -i '/{OLDSUFF}/c:' support/shlib-install && \
    ./configure --prefix=/usr    \
        --disable-static \
        --docdir=/usr/share/doc/readline-8.0 && \
    make SHLIB_LIBS="-L/tools/lib -lncursesw" && \
    make SHLIB_LIBS="-L/tools/lib -lncursesw" install && \
    mv -v /usr/lib/lib{readline,history}.so.* /lib && \
    chmod -v u+w /lib/lib{readline,history}.so.* && \
    ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so && \
    ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so && \
    install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.0 && \
    cd /usr/src && \
    rm -Rf readline-8.0

RUN set +o hashall && \
    tar xf m4-1.4.18.tar.xz && \
    cd m4-1.4.18 && \
    sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c && \
    echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h && \
    ./configure --prefix=/usr && \
    make && \
    make check && \
    make install && \
    cd /usr/src && \
    rm -Rf m4-1.4.18

RUN set +o hashall && \
    tar xf bc-2.4.0.tar.gz && \
    cd bc-2.4.0 && \
    export PREFIX=/usr && \
    export CC=gcc && \
    export CFLAGS="-std=c99" && \
    ./configure.sh -G -O3 && \
    make && \
    make test && \
    make install && \
    cd /usr/src && \
    rm -Rf bc-2.4.0

RUN set +o hashall && \
    tar xf binutils-2.33.1.tar.xz && \
    cd binutils-2.33.1 && \
    sed -i '/@\tincremental_copy/d' gold/testsuite/Makefile.in && \
    mkdir -v build && \
    cd build && \
    ../configure --prefix=/usr       \
        --enable-gold       \
        --enable-ld=default \
        --enable-plugins    \
        --enable-shared     \
        --disable-werror    \
        --enable-64-bit-bfd \
        --with-system-zlib && \
    make tooldir=/usr && \
    #make -k check && \
    make tooldir=/usr install && \
    cd /usr/src && \
    rm -Rf binutils-2.33.1

RUN set +o hashall && \
    tar xf gmp-6.1.2.tar.xz && \
    cd gmp-6.1.2 && \
    cp -v configfsf.guess config.guess && \
    cp -v configfsf.sub   config.sub && \
    ./configure --prefix=/usr    \
        --enable-cxx     \
        --disable-static \
        --build=x86_64-unknown-linux-gnu \
        --docdir=/usr/share/doc/gmp-6.1.2 && \
    make && \
    make html && \
    make check 2>&1 | tee gmp-check-log && \
    awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log && \
    make install && \
    make install-html && \
    cd /usr/src && \
    rm -Rf gmp-6.1.2

RUN set +o hashall && \
    tar xf mpfr-4.0.2.tar.xz && \
    cd mpfr-4.0.2 && \
    ./configure --prefix=/usr        \
        --disable-static     \
        --enable-thread-safe \
        --docdir=/usr/share/doc/mpfr-4.0.2 && \
    make && \
    make html && \
    make check && \
    make install && \
    make install-html && \
    cd /usr/src && \
    rm -Rf mpfr-4.0.2

RUN set +o hashall && \
    tar xf mpc-1.1.0.tar.gz && \
    cd mpc-1.1.0 && \
    ./configure --prefix=/usr    \
        --disable-static \
        --docdir=/usr/share/doc/mpc-1.1.0 && \
    make && \
    make html && \
    make check && \
    make install && \
    make install-html && \
    cd /usr/src && \
    rm -Rf mpc-1.1.0

RUN set +o hashall && \
    tar xf shadow-4.8.tar.xz && \
    cd shadow-4.8 && \
    sed -i 's/groups$(EXEEXT) //' src/Makefile.in && \
    find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \; && \
    find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \; && \
    find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \; && \
    sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' etc/login.defs && \
    sed -i 's/1000/999/' etc/useradd && \
    ./configure --sysconfdir=/etc --with-group-name-max-length=32 && \
    make && \
    make install && \
    mv -v /usr/bin/passwd /bin || ls -l /bin/passwd && \
    pwconv && \
    grpconv && \
    sed -i 's/yes/no/' /etc/default/useradd && \
    usermod -p ! root && \
    cd /usr/src && \
    rm -Rf shadow-4.8

RUN set +o hashall && \
    tar xf gcc-9.2.0.tar.xz && \
    cd gcc-9.2.0 && \
    bash -c 'case $(uname -m) in x86_64) sed -e "/m64=/s/lib64/lib/" -i.orig gcc/config/i386/t-linux64 ;; esac' && \
    mkdir -v build && \
    cd build && \
    export SED=sed && \
    ../configure --prefix=/usr            \
        --enable-languages=c,c++ \
        --disable-multilib       \
        --disable-bootstrap      \
        --with-system-zlib && \
    make && \
    chown -R nobody . && \
    #su nobody -s /bin/bash -c "PATH=$PATH make -k check" && \
    #../contrib/test_summary && \
    make install && \
    rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/9.2.0/include-fixed/bits/ && \
    chown -v -R root:root \
        /usr/lib/gcc/*linux-gnu/9.2.0/include{,-fixed} && \
    ln -sv ../usr/bin/cpp /lib && \
    ln -sv gcc /usr/bin/cc && \
    install -v -dm755 /usr/lib/bfd-plugins && \
    ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/9.2.0/liblto_plugin.so \
            /usr/lib/bfd-plugins/ && \
    echo 'int main(){}' > dummy.c && \
    cc dummy.c -v -Wl,--verbose &> dummy.log && \
    readelf -l a.out | grep ': /lib' && \
    grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log && \
    grep -B4 '^ /usr/include' dummy.log && \
    grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g' && \
    grep "/lib.*/libc.so.6 " dummy.log && \
    grep found dummy.log && \
    rm -v dummy.c a.out dummy.log && \
    mkdir -pv /usr/share/gdb/auto-load/usr/lib && \
    mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib && \
    cd /usr/src && \
    rm -Rf gcc-9.2.0

RUN set +o hashall && \
    tar xf bzip2-1.0.8.tar.gz && \
    cd bzip2-1.0.8 && \
    patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch && \
    sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile && \
    sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile && \
    make -f Makefile-libbz2_so && \
    make clean && \
    make && \
    make PREFIX=/usr install && \
    cp -v bzip2-shared /bin/bzip2 && \
    cp -av libbz2.so* /lib && \
    ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so && \
    rm -v /usr/bin/{bunzip2,bzcat,bzip2} && \
    ln -sv bzip2 /bin/bunzip2 && \
    ln -sv bzip2 /bin/bzcat && \
    cd /usr/src && \
    rm -Rf bzip2-1.0.8

RUN set +o hashall && \
    tar xf pkg-config-0.29.2.tar.gz && \
    cd pkg-config-0.29.2 && \
    ./configure --prefix=/usr              \
            --with-internal-glib       \
            --disable-host-tool        \
            --docdir=/usr/share/doc/pkg-config-0.29.2 && \
    make && \
    make check && \
    make install && \
    cd /usr/src && \
    rm -Rf pkg-config-0.29.2

RUN set +o hashall && \
    tar xf ncurses-6.1.tar.gz && \
    cd ncurses-6.1 && \
    sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in && \
    ./configure --prefix=/usr           \
        --mandir=/usr/share/man \
        --with-shared           \
        --without-debug         \
        --without-normal        \
        --enable-pc-files       \
        --enable-widec && \
    make && \
    make install && \
    mv -v /usr/lib/libncursesw.so.6* /lib && \
    ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so && \
    bash -c 'for lib in ncurses form panel menu ; do \
        rm -vf                    /usr/lib/lib${lib}.so && \
        echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so && \
        ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc ; \
    done' && \
    rm -vf                     /usr/lib/libcursesw.so && \
    echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so && \
    ln -sfv libncurses.so      /usr/lib/libcurses.so && \
    mkdir -v       /usr/share/doc/ncurses-6.1 && \
    cp -v -R doc/* /usr/share/doc/ncurses-6.1 && \
    make distclean && \
    ./configure --prefix=/usr    \
                --with-shared    \
                --without-normal \
                --without-debug  \
                --without-cxx-binding \
                --with-abi-version=5 && \
    make sources libs && \
    cp -av lib/lib*.so.5* /usr/lib && \
    cd /usr/src && \
    rm -Rf ncurses-6.1

RUN set +o hashall && \
    tar xf attr-2.4.48.tar.gz && \
    cd attr-2.4.48 && \
    ./configure --prefix=/usr     \
            --bindir=/bin     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.4.48 && \
    make && \
    #make check && \
    make install && \
    mv -v /usr/lib/libattr.so.* /lib && \
    ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so && \
    cd /usr/src && \
    rm -Rf attr-2.4.48

RUN set +o hashall && \
    tar xf acl-2.2.53.tar.gz && \
    cd acl-2.2.53 && \
    ./configure --prefix=/usr         \
            --bindir=/bin         \
            --disable-static      \
            --libexecdir=/usr/lib \
            --docdir=/usr/share/doc/acl-2.2.53 && \
    make && \
    make install && \
    mv -v /usr/lib/libacl.so.* /lib && \
    ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so && \
    cd /usr/src && \
    rm -Rf acl-2.2.53

RUN set +o hashall && \
    tar xf libcap-2.27.tar.xz && \
    cd libcap-2.27 && \
    sed -i '/install.*STALIBNAME/d' libcap/Makefile && \
    make && \
    make RAISE_SETFCAP=no lib=lib prefix=/usr install && \
    chmod -v 755 /usr/lib/libcap.so.2.27 && \
    mv -v /usr/lib/libcap.so.* /lib && \
    ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so && \
    cd /usr/src && \
    rm -Rf libcap-2.27.tar.xz

RUN set +o hashall && \
    tar xf sed-4.7.tar.xz && \
    cd sed-4.7 && \
    sed -i 's/usr/tools/'                 build-aux/help2man && \
    sed -i 's/testsuite.panic-tests.sh//' Makefile.in && \
    ./configure --prefix=/usr --bindir=/bin && \
    make && \
    make html && \
    #make check && \
    make install && \
    install -d -m755           /usr/share/doc/sed-4.7 && \
    install -m644 doc/sed.html /usr/share/doc/sed-4.7 && \
    cd /usr/src && \
    rm -Rf sed-4.7

RUN set +o hashall && \
    tar xf psmisc-23.2.tar.xz && \
    cd psmisc-23.2 && \
    ./configure --prefix=/usr && \
    make && \
    make install && \
    mv -v /usr/bin/fuser   /bin && \
    mv -v /usr/bin/killall /bin && \
    cd /usr/src && \
    rm -Rf psmisc-23.2

RUN set +o hashall && \
    tar xf iana-etc-2.30.tar.bz2 && \
    cd iana-etc-2.30 && \
    make && \
    make install && \
    cd /usr/src && \
    rm -Rf iana-etc-2.30

RUN set +o hashall && \
    tar xf bison-3.4.2.tar.xz && \
    cd bison-3.4.2 && \
    sed -i '6855 s/mv/cp/' Makefile.in && \
    ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.4.1 && \
    make -j1 && \
    make install && \
    cd /usr/src && \
    rm -Rf bison-3.4.2

RUN set +o hashall && \
    tar xf flex-2.6.4.tar.gz && \
    cd flex-2.6.4 && \
    sed -i "/math.h/a #include <malloc.h>" src/flexdef.h && \
    export HELP2MAN=/tools/bin/true && \
    ./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4 && \
    make && \
    make check && \
    make install && \
    ln -sv flex /usr/bin/lex && \
    cd /usr/src && \
    rm -Rf flex-2.6.4

RUN set +o hashall && \
    tar xf grep-3.3.tar.xz && \
    cd grep-3.3 && \
    ./configure --prefix=/usr --bindir=/bin && \
    make && \
    make -k check && \
    make install && \
    cd /usr/src && \
    rm -Rf grep-3.3

RUN set +o hashall && \
    tar xf bash-5.0.tar.gz && \
    cd bash-5.0 && \
    ./configure --prefix=/usr                    \
            --docdir=/usr/share/doc/bash-5.0 \
            --without-bash-malloc            \
            --with-installed-readline && \
    make && \
    chown -Rv nobody . && \
    su nobody -s /bin/bash -c "PATH=$PATH HOME=/home make tests" && \
    make install && \
    mv -vf /usr/bin/bash /bin && \
    cd /usr/src && \
    rm -Rf bash-5.0

RUN set +o hashall && \
    tar xf libtool-2.4.6.tar.xz && \
    cd libtool-2.4.6 && \
    ./configure --prefix=/usr && \
    make && \
    #make check TESTSUITEFLAGS=-j4 && \
    make install && \
    cd /usr/src && \
    rm -Rf libtool-2.4.6

RUN set +o hashall && \
    tar xf gdbm-1.18.1.tar.gz && \
    cd gdbm-1.18.1 && \
    ./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat && \
    make && \
    make check && \
    make install && \
    cd /usr/src && \
    rm -Rf gdbm-1.18.1

RUN set +o hashall && \
    tar xf gperf-3.1.tar.gz && \
    cd gperf-3.1 && \
    ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1 && \
    make && \
    make -j1 check && \
    make install && \
    cd /usr/src && \
    rm -Rf gperf-3.1

RUN set +o hashall && \
    tar xf expat-2.2.9.tar.xz && \
    cd expat-2.2.9 && \
    sed -i 's|usr/bin/env |bin/|' run.sh.in && \
    ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.2.9 && \
    make && \
    make check && \
    make install && \
    install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.9 && \
    cd /usr/src && \
    rm -Rf expat-2.2.9

RUN set +o hashall && \
    tar xf inetutils-1.9.4.tar.xz && \
    cd inetutils-1.9.4 && \
    ./configure --prefix=/usr        \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers && \
    make && \
    #make check && \
    make install && \
    mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin && \
    mv -v /usr/bin/ifconfig /sbin && \
    cd /usr/src && \
    rm -Rf inetutils-1.9.4

RUN set +o hashall && \
    tar xf perl-5.30.1.tar.xz && \
    cd perl-5.30.1 && \
    echo "127.0.0.1 localhost $(hostname)" > /etc/hosts && \
    export BUILD_ZLIB=False && \
    export BUILD_BZIP2=0 && \
    sh Configure -des -Dprefix=/usr               \
                    -Dvendorprefix=/usr           \
                    -Dman1dir=/usr/share/man/man1 \
                    -Dman3dir=/usr/share/man/man3 \
                    -Dpager="/usr/bin/less -isR"  \
                    -Duseshrplib                  \
                    -Dusethreads && \
    make && \
    make -k test && \
    make install && \
    cd /usr/src && \
    rm -Rf perl-5.30.1

RUN set +o hashall && \
    tar xf XML-Parser-2.46.tar.gz && \
    cd XML-Parser-2.46 && \
    perl Makefile.PL && \
    make && \
    make test && \
    make install && \
    cd /usr/src && \
    rm -Rf XML-Parser-2.46

RUN set +o hashall && \
    tar xf intltool-0.51.0.tar.gz && \
    cd intltool-0.51.0 && \
    sed -i 's:\\\${:\\\$\\{:' intltool-update.in && \
    ./configure --prefix=/usr && \
    make && \
    make check && \
    make install && \
    install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO && \
    cd /usr/src && \
    rm -Rf intltool-0.51.0

RUN set +o hashall && \
    tar xf autoconf-2.69.tar.xz && \
    cd autoconf-2.69 && \
    sed '361 s/{/\\{/' -i bin/autoscan.in && \
    ./configure --prefix=/usr && \
    make && \
    #make check && \
    make install && \
    cd /usr/src && \
    rm -Rf autoconf-2.69

RUN set +o hashall && \
    tar xf automake-1.16.1.tar.xz && \
    cd automake-1.16.1 && \
    ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.1 && \
    make && \
    make -j4 check && \
    make install && \
    cd /usr/src && \
    rm -Rf automake-1.16.1

RUN set +o hashall && \
    tar xf xz-5.2.4.tar.xz && \
    cd xz-5.2.4 && \
    ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.2.4 && \
    make && \
    make check && \
    make install && \
    mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin && \
    mv -v /usr/lib/liblzma.so.* /lib && \
    ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so && \
    cd /usr/src && \
    rm -Rf xz-5.2.4

RUN set +o hashall && \
    tar xf kmod-26.tar.xz && \
    cd kmod-26 && \
    ./configure --prefix=/usr          \
            --bindir=/bin          \
            --sysconfdir=/etc      \
            --with-rootlibdir=/lib \
            --with-xz              \
            --with-zlib && \
    make && \
    make install && \
    bash -c 'for target in depmod insmod lsmod modinfo modprobe rmmod ; do \
                ln -sfv ../bin/kmod /sbin/$target ; \
             done' && \
    ln -sfv kmod /bin/lsmod && \
    cd /usr/src && \
    rm -Rf kmod-26

RUN set +o hashall && \
    tar xf gettext-0.20.1.tar.xz && \
    cd gettext-0.20.1 && \
    ./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.20.1 && \
    make && \
    make check && \
    make install && \
    chmod -v 0755 /usr/lib/preloadable_libintl.so && \
    cd /usr/src && \
    rm -Rf gettext-0.20.1

RUN set +o hashall && \
    tar xf elfutils-0.178.tar.bz2 && \
    cd elfutils-0.178 && \
    ./configure --prefix=/usr --disable-debuginfod && \
    make && \
    #make check && \
    make -C libelf install && \
    install -vm644 config/libelf.pc /usr/lib/pkgconfig && \
    cd /usr/src && \
    rm -Rf elfutils-0.178

RUN set +o hashall && \
    tar xf libffi-3.3.tar.gz && \
    cd libffi-3.3 && \
    sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
    -i include/Makefile.in && \
    sed -e '/^includedir/ s/=.*$/=@includedir@/' \
        -e 's/^Cflags: -I${includedir}/Cflags:/' \
        -i libffi.pc.in && \
    ./configure --prefix=/usr --disable-static --with-gcc-arch=native && \
    make && \
    #make check && \
    make install && \
    cd /usr/src && \
    rm -Rf libffi-3.3

RUN set +o hashall && \
    tar xf openssl-1.1.1d.tar.gz && \
    cd openssl-1.1.1d && \
    sed -i '/\} data/s/ =.*$/;\n    memset(\&data, 0, sizeof(data));/' \
        crypto/rand/rand_lib.c && \
    ./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic && \
    make && \
    #make test && \
    sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile && \
    make MANSUFFIX=ssl install && \
    mv -v /usr/share/doc/openssl /usr/share/doc/openssl-1.1.1c && \
    cp -vfr doc/* /usr/share/doc/openssl-1.1.1c && \
    cd /usr/src && \
    rm -Rf openssl-1.1.1d

RUN set +o hashall && \
    tar xf Python-3.8.0.tar.xz && \
    cd Python-3.8.0 && \
    ./configure --prefix=/usr       \
            --enable-shared     \
            --with-system-expat \
            --with-system-ffi   \
            --with-ensurepip=yes && \
    make && \
    make install && \
    chmod -v 755 /usr/lib/libpython3.8.so && \
    chmod -v 755 /usr/lib/libpython3.so && \
    ln -sfv pip3.8 /usr/bin/pip3 && \
    install -v -dm755 /usr/share/doc/python-3.8.0/html && \
    tar --strip-components=1  \
        --no-same-owner       \
        --no-same-permissions \
        -C /usr/share/doc/python-3.8.0/html \
        -xvf ../python-3.8.0-docs-html.tar.bz2 && \
    cd /usr/src && \
    rm -Rf Python-3.8.0

RUN set +o hashall && \
    tar xf ninja-1.9.0.tar.gz && \
    cd ninja-1.9.0 && \
    sed -i '/int Guess/a \
        int   j = 0;\
        char* jobs = getenv( "NINJAJOBS" );\
        if ( jobs != NULL ) j = atoi( jobs );\
        if ( j > 0 ) return j;\
        ' src/ninja.cc && \
    python3 configure.py --bootstrap && \
    ./ninja ninja_test && \
    ./ninja_test --gtest_filter=-SubprocessTest.SetWithLots && \
    install -vm755 ninja /usr/bin/ && \
    install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja && \
    install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja && \
    cd /usr/src && \
    rm -Rf ninja-1.9.0

RUN set +o hashall && \
    tar xf meson-0.52.1.tar.gz && \
    cd meson-0.52.1 && \
    python3 setup.py build && \
    python3 setup.py install --root=dest && \
    cp -rv dest/* / && \
    cd /usr/src && \
    rm -Rf meson-0.52.1

RUN set +o hashall && \
    tar xf coreutils-8.31.tar.xz && \
    cd coreutils-8.31 && \
    patch -Np1 -i ../coreutils-8.31-i18n-1.patch && \
    sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk && \
    autoreconf -fiv && \
    FORCE_UNSAFE_CONFIGURE=1 ./configure \
                --prefix=/usr            \
                --enable-no-install-program=kill,uptime && \
    make && \
    #make NON_ROOT_USERNAME=nobody check-root && \
    #echo "dummy:x:1000:nobody" >> /etc/group && \
    #chown -Rv nobody . && \
    #su nobody -s /bin/bash \
    #      -c "PATH=$PATH make RUN_EXPENSIVE_TESTS=yes check" && \
    #sed -i '/dummy/d' /etc/group && \
    make install && \
    mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin && \
    mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin && \
    mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin && \
    mv -v /usr/bin/chroot /usr/sbin && \
    mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8 && \
    sed -i 's/"1"/"8"/1' /usr/share/man/man8/chroot.8 && \
    mv -v /usr/bin/{head,nice,sleep,touch} /bin && \
    cd /usr/src && \
    rm -Rf coreutils-8.31

RUN set +o hashall && \
    tar xf check-0.13.0.tar.gz && \
    cd check-0.13.0 && \
    ./configure --prefix=/usr && \
    make && \
    make check && \
    make docdir=/usr/share/doc/check-0.12.0 install && \
    sed -i '1 s/tools/usr/' /usr/bin/checkmk && \
    cd /usr/src && \
    rm -Rf check-0.13.0

RUN set +o hashall && \
    tar xf diffutils-3.7.tar.xz && \
    cd diffutils-3.7 && \
    ./configure --prefix=/usr && \
    make && \
    make check && \
    make install && \
    cd /usr/src && \
    rm -Rf diffutils-3.7

RUN set +o hashall && \
    tar xf gawk-5.0.1.tar.xz && \
    cd gawk-5.0.1 && \
    sed -i 's/extras//' Makefile.in && \
    ./configure --prefix=/usr && \
    make && \
    make check && \
    make install && \
    mkdir -v /usr/share/doc/gawk-5.0.1 && \
    cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.0.1 && \
    cd /usr/src && \
    rm -Rf gawk-5.0.1

RUN set +o hashall && \
    tar xf findutils-4.7.0.tar.xz && \
    cd findutils-4.7.0 && \
    ./configure --prefix=/usr --localstatedir=/var/lib/locate && \
    make && \
    #make check && \
    make install && \
    mv -v /usr/bin/find /bin && \
    sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb && \
    cd /usr/src && \
    rm -Rf findutils-4.7.0

RUN set +o hashall && \
    tar xf groff-1.22.4.tar.gz && \
    cd groff-1.22.4 && \
    PAGE=A4 ./configure --prefix=/usr && \
    make -j1 && \
    make install && \
    cd /usr/src && \
    rm -Rf groff-1.22.4

RUN set +o hashall && \
    tar xf grub-2.04.tar.xz && \
    cd grub-2.04 && \
    ./configure --prefix=/usr          \
            --sbindir=/sbin        \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror && \
    make && \
    make install && \
    mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions && \
    cd /usr/src && \
    rm -Rf grub-2.04

RUN set +o hashall && \
    tar xf less-551.tar.gz && \
    cd less-551 && \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make && \
    make install && \
    cd /usr/src && \
    rm -Rf less-551

RUN set +o hashall && \
    tar xf gzip-1.10.tar.xz && \
    cd gzip-1.10 && \
    ./configure --prefix=/usr && \
    make && \
    #make check && \
    make install && \
    mv -v /usr/bin/gzip /bin && \
    cd /usr/src && \
    rm -Rf gzip-1.10

RUN set +o hashall && \
    tar xf iproute2-5.4.0.tar.xz && \
    cd iproute2-5.4.0 && \
    sed -i /ARPD/d Makefile && \
    rm -fv man/man8/arpd.8 && \
    sed -i 's/.m_ipt.o//' tc/Makefile && \
    make && \
    make DOCDIR=/usr/share/doc/iproute2-5.2.0 install && \
    cd /usr/src && \
    rm -Rf iproute2-5.4.0

RUN set +o hashall && \
    tar xf kbd-2.2.0.tar.xz && \
    cd kbd-2.2.0 && \
    patch -Np1 -i ../kbd-2.2.0-backspace-1.patch && \
    sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure && \
    sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in && \
    PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock && \
    make && \
    make check && \
    make install && \
    mkdir -v       /usr/share/doc/kbd-2.2.0 && \
    cp -R -v docs/doc/* /usr/share/doc/kbd-2.2.0 && \
    cd /usr/src && \
    rm -Rf kbd-2.2.0

RUN set +o hashall && \
    tar xf libpipeline-1.5.1.tar.gz && \
    cd libpipeline-1.5.1 && \
    ./configure --prefix=/usr && \
    make && \
    make check && \
    make install && \
    cd /usr/src && \
    rm -Rf libpipeline-1.5.1

RUN set +o hashall && \
    tar xf make-4.2.1.tar.gz && \
    cd make-4.2.1 && \
    sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c && \
    ./configure --prefix=/usr && \
    make && \
    make PERL5LIB=$PWD/tests/ check && \
    make install && \
    cd /usr/src && \
    rm -Rf make-4.2.1

RUN set +o hashall && \
    tar xf patch-2.7.6.tar.xz && \
    cd patch-2.7.6 && \
    ./configure --prefix=/usr && \
    make && \
    make check && \
    make install && \
    cd /usr/src && \
    rm -Rf patch-2.7.6

RUN set +o hashall && \
    tar xf man-db-2.9.0.tar.xz && \
    cd man-db-2.9.0 &&\
    ./configure --prefix=/usr                        \
            --docdir=/usr/share/doc/man-db-2.8.6.1 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap            \
            --with-systemdtmpfilesdir=           \
            --with-systemdsystemunitdir= && \
    make && \
    make check && \
    make install && \
    cd /usr/src && \
    rm -Rf man-db-2.9.0

RUN set +o hashall && \
    tar xf tar-1.32.tar.xz && \
    cd tar-1.32 && \
    FORCE_UNSAFE_CONFIGURE=1  \
    ./configure --prefix=/usr \
            --bindir=/bin && \
    make && \
    #make check && \
    make install && \
    make -C doc install-html docdir=/usr/share/doc/tar-1.32 && \
    cd /usr/src && \
    rm -Rf tar-1.32

RUN set +o hashall && \
    tar xf texinfo-6.7.tar.xz && \
    cd texinfo-6.7 && \
    ./configure --prefix=/usr --disable-static && \
    make && \
    make check && \
    make install && \
    make TEXMF=/usr/share/texmf install-tex && \
    cd /usr/src && \
    rm -Rf texinfo-6.7

RUN set +o hashall && \
    tar xf vim-8.1.2361.tar.gz && \
    cd vim-8.1.2361 && \
    echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h && \
    ./configure --prefix=/usr && \
    make && \
    #chown -R nobody . && \
    #su nobody -s /bin/bash -c "LANG=en_US.UTF-8 make -j1 test" && \
    make install && \
    ln -sv vim /usr/bin/vi && \
    bash -c 'for L in  /usr/share/man/{,*/}man1/vim.1; do \
        ln -sv vim.1 $(dirname $L)/vi.1 ; \
    done' && \
    cd /usr/src && \
    rm -Rf vim-8.1.2361

COPY files/etc/vimrc /etc/vimrc

RUN set +o hashall && \
    tar xf procps-ng-3.3.15.tar.xz && \
    cd procps-ng-3.3.15 && \
    ./configure --prefix=/usr                            \
            --exec-prefix=                           \
            --libdir=/usr/lib                        \
            --docdir=/usr/share/doc/procps-ng-3.3.15 \
            --disable-static                         \
            --disable-kill && \
    make && \
    sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp && \
    sed -i '/set tty/d' testsuite/pkill.test/pkill.exp && \
    rm testsuite/pgrep.test/pgrep.exp && \
    make check && \
    make install && \
    mv -v /usr/lib/libprocps.so.* /lib && \
    ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so && \
    cd /usr/src && \
    rm -Rf procps-ng-3.3.15

RUN set +o hashall && \
    tar xf util-linux-2.34.tar.xz && \
    cd util-linux-2.34 && \
    mkdir -pv /var/lib/hwclock && \
    ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
            --docdir=/usr/share/doc/util-linux-2.34 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            --without-systemd    \
            --without-systemdsystemunitdir && \
    make && \
    #chown -Rv nobody . && \
    #su nobody -s /bin/bash -c "PATH=$PATH make -k check" && \
    make install && \
    cd /usr/src && \
    rm -Rf util-linux-2.34

RUN set +o hashall && \
    tar xf e2fsprogs-1.45.4.tar.gz && \
    cd e2fsprogs-1.45.4 && \
    mkdir -v build && \
    cd       build && \
    ../configure --prefix=/usr           \
             --bindir=/bin           \
             --with-root-prefix=""   \
             --enable-elf-shlibs     \
             --disable-libblkid      \
             --disable-libuuid       \
             --disable-uuidd         \
             --disable-fsck && \
    make && \
    make check && \
    make install && \
    make install-libs && \
    chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a && \
    gunzip -v /usr/share/info/libext2fs.info.gz && \
    install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info && \
    makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo && \
    install -v -m644 doc/com_err.info /usr/share/info && \
    install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info && \
    cd /usr/src && \
    rm -Rf e2fsprogs-1.45.4

RUN set +o hashall && \
    tar xf sysklogd-1.5.1.tar.gz && \
    cd sysklogd-1.5.1 && \
    sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c && \
    sed -i 's/union wait/int/' syslogd.c && \
    make && \
    make BINDIR=/sbin install && \
    cd /usr/src && \
    rm -Rf sysklogd-1.5.1

COPY files/etc/syslog.conf /etc/syslog.conf

RUN set +o hashall && \
    tar xf sysvinit-2.96.tar.xz && \
    cd sysvinit-2.96 && \
    patch -Np1 -i ../sysvinit-2.96-consolidated-1.patch && \
    make && \
    make install && \
    cd /usr/src && \
    rm -Rf sysvinit-2.96

RUN set +o hashall && \
    tar xf eudev-3.2.9.tar.gz && \
    cd eudev-3.2.9 && \
    ./configure --prefix=/usr           \
                --bindir=/sbin          \
                --sbindir=/sbin         \
                --libdir=/usr/lib       \
                --sysconfdir=/etc       \
                --libexecdir=/lib       \
                --with-rootprefix=      \
                --with-rootlibdir=/lib  \
                --enable-manpages       \
                --disable-static && \
    make && \
    mkdir -pv /lib/udev/rules.d && \
    mkdir -pv /etc/udev/rules.d &&\
    #make check && \
    make install && \
    tar -xvf ../udev-lfs-20171102.tar.xz && \
    make -f udev-lfs-20171102/Makefile.lfs install && \
    udevadm hwdb --update && \
    cd /usr/src && \
    rm -Rf eudev-3.2.9

RUN tar xf lfs-bootscripts-20191031.tar.xz && \
    cd lfs-bootscripts-20191031 && \
    make install && \
    cd /usr/src && \
    rm -Rf lfs-bootscripts-20191031

RUN echo "127.0.0.1 localhost" > /etc/hosts && \
    echo "::1       localhost ip6-localhost ip6-loopback" >> /etc/hosts && \
    echo "ff02::1   ip6-allnodes" >> /etc/hosts && \
    echo "ff02::2   ip6-allrouters" >> /etc/hosts

COPY files/etc/inittab /etc/inittab
COPY files/etc/sysconfig/clock /etc/sysconfig/clock
COPY files/etc/sysconfig/console /etc/sysconfig/console
COPY files/etc/sysconfig/rc.site /etc/sysconfig/rc.site
COPY files/etc/inputrc /etc/inputrc
COPY files/etc/shells /etc/shells
COPY files/etc/fstab /etc/fstab

RUN touch /etc/profile

RUN tar xf which-2.21.tar.gz && \
    cd which-2.21 && \
    ./configure --prefix=/usr && \
    make && \
    make install && \
    cd /usr/src && \
    rm -Rf which-2.21

RUN tar xf cpio-2.13.tar.bz2 && \
    cd cpio-2.13 && \
    ./configure --prefix=/usr \
            --bindir=/bin \
            --enable-mt   \
            --with-rmt=/usr/libexec/rmt && \
    make && \
    makeinfo --html            -o doc/html      doc/cpio.texi && \
    makeinfo --html --no-split -o doc/cpio.html doc/cpio.texi && \
    makeinfo --plaintext       -o doc/cpio.txt  doc/cpio.texi && \
    make install && \
    install -v -m755 -d /usr/share/doc/cpio-2.13/html && \
    install -v -m644    doc/html/* \
                        /usr/share/doc/cpio-2.13/html && \
    install -v -m644    doc/cpio.{html,txt} \
                        /usr/share/doc/cpio-2.13 && \
    cd /usr/src && \
    rm -Rf cpio-2.13

RUN tar xf linux-5.4.2.tar.xz && \
    chown -R 0:0 linux-5.4.2 && \
    cd linux-5.4.2 && \
    make mrproper && \
    make allmodconfig && \
    make && \
    make modules_install && \
    cp -iv arch/x86/boot/bzImage /boot/vmlinuz-5.4.2 && \
    cp -iv System.map /boot/System.map-5.4.2 && \
    cp -iv .config /boot/config-5.4.2 && \
    install -d /usr/share/doc/linux-5.2.8 && \
    cp -r Documentation/* /usr/share/doc/linux-5.2.8 && \
    install -v -m755 -d /etc/modprobe.d && \
    cd /usr/src && \
    rm -Rf linux-5.4.2

COPY files/etc/modprobe.d/usb.conf /etc/modprobe.d/usb.conf

RUN /tools/bin/find /usr/lib -type f -name \*.a \
   -exec /tools/bin/strip --strip-debug {} ';'

RUN /tools/bin/find /lib /usr/lib -type f \( -name \*.so* -a ! -name \*dbg \) \
   -exec /tools/bin/strip --strip-unneeded {} ';'

RUN /tools/bin/find /{bin,sbin} /usr/{bin,sbin,libexec} -type f \
    -exec /tools/bin/strip --strip-all {} ';'

RUN rm -Rf /tmp/* && \
    rm -f /usr/lib/lib{bfd,opcodes}.a && \
    rm -f /usr/lib/libbz2.a && \
    rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a && \
    rm -f /usr/lib/libltdl.a && \
    rm -f /usr/lib/libfl.a && \
    rm -f /usr/lib/libz.a && \
    find /usr/lib /usr/libexec -name \*.la -delete && \
    rm -Rf /tools \
           /usr/src/* \
           /scripts 

ENV PS1 '\u:\w\$ '

WORKDIR /root
ENTRYPOINT [ "/bin/bash" ]

