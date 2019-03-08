#!/bin/bash -e

cacher="10.1.1.81:3142/"

function makeit_debootstrap() {
    arch=$1
    vers=$2

    rm -rf build
    mkdir build

    echo "Building debian $vers for $arch"
    sudo debootstrap --variant=minbase --include sysvinit-core --foreign --arch=${arch} ${vers} build http://${cacher}ftp.de.debian.org/debian/
    sudo sed -i -e 's/systemd systemd-sysv //g' build/debootstrap/required
    sudo chroot build debootstrap/debootstrap --second-stage
    sudo tar -C build -czf img.tgz .
    sudo rm -rf build
    echo "FROM scratch" > Dockerfile
    echo "MAINTAINER \"Gerd Pauli <gp@high-consulting.de>\"" >> Dockerfile
    echo "ADD img.tgz /" >> Dockerfile
    echo "RUN #(nop) debootstrap --variant=minbase --arch=${arch} ${vers}\"" >> Dockerfile
    echo "CMD [\"/bin/bash\"]" >> Dockerfile
    echo "RUN /bin/sh -c set -xe && echo '#!/bin/sh' > /usr/sbin/policy-rc.d  && echo 'exit 101' >> /usr/sbin/policy-rc.d  && chmod +x /usr/sbin/policy-rc.d   && dpkg-divert --local --rename --add /sbin/initctl  && cp -a /usr/sbin/policy-rc.d /sbin/initctl  && sed -i 's/^exit.*/exit 0/' /sbin/initctl   && echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup   && echo 'DPkg::Post-Invoke { \"rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true\"; };' > /etc/apt/apt.conf.d/docker-clean  && echo 'APT::Update::Post-Invoke { \"rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true\"; };' >> /etc/apt/apt.conf.d/docker-clean  && echo 'Dir::Cache::pkgcache \"\"; Dir::Cache::srcpkgcache \"\";' >> /etc/apt/apt.conf.d/docker-clean   && echo 'Acquire::Languages \"none\";' > /etc/apt/apt.conf.d/docker-no-languages   && echo 'Acquire::GzipIndexes \"true\"; Acquire::CompressionTypes::Order:: \"gz\";' > /etc/apt/apt.conf.d/docker-gzip-indexes   && echo 'Apt::AutoRemove::SuggestsImportant \"false\";' > /etc/apt/apt.conf.d/docker-autoremove-suggests" >> Dockerfile
    echo "RUN /bin/sh -c set -xe && echo 'deb http://${cacher}ftp.de.debian.org/debian/ ${vers} main contrib non-free' > /etc/apt/sources.list && echo 'deb http://${cacher}ftp.de.debian.org/debian/ ${vers}-updates main contrib non-free' >> /etc/apt/sources.list && echo 'deb http://${cacher}security.debian.org/ ${vers}/updates main contrib non-free' >> /etc/apt/sources.list" >> Dockerfile
    echo "RUN /bin/sh -c set -xe && echo 'Package: *systemd*' > /etc/apt/preferences && echo 'Pin: release *' >> /etc/apt/preferences && echo 'Pin-Priority: -1' >> /etc/apt/preferences && echo >> /etc/apt/preferences" >> Dockerfile
    echo "RUN apt-get update" >> Dockerfile
    echo "RUN DEBCONF_FRONTEND=noninteractive DEBIAN_FRONTEND=noninteractive apt-get -q --force-yes --yes upgrade" >> Dockerfile
    echo "RUN apt-get clean" >> Dockerfile
    echo "RUN rm -rf /var/lib/apt/lists/*" >> Dockerfile
    echo "RUN cat /etc/debian_version" >> Dockerfile
    docker build -t makeit_debootstrap .
    v=`docker run --rm -it makeit_debootstrap cat /etc/debian_version | sed 's/\r//'`
    docker tag makeit_debootstrap debian-mini-${arch}:${v}
    docker rmi makeit_debootstrap
    sudo rm -f img.tgz
    rm -f Dockerfile
}


makeit_debootstrap i386 jessie
makeit_debootstrap amd64 jessie





