FROM debian:bullseye-slim
ENV DEBIAN_FRONTEND=noninteractive
ENV DOCKER="YES"
ENV DEV="autoconf automake build-essential cmake git pkg-config texinfo curl wget libtool nasm yasm gzip gperf uuid-dev gettext autopoint zip ninja-build unzip"

RUN set -x && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install $DEV apt-utils locales gnupg wget \
    ca-certificates locales tzdata \
    python3 python3-pip python3-setuptools \
    git make g++ yasm vim less curl cron libxml2-dev libxslt1-dev \
    libva-dev libmp3lame-dev \
    v4l-utils libv4l-dev \
    libx264-dev libx265-dev libnuma-dev && \
    echo "ja_JP UTF-8" > /etc/locale.gen && \
    locale-gen ja_JP.UTF-8

ENV TZ=Asia/Tokyo
ENV LANG=ja_JP.UTF-8
ENV LANGUAGE=ja_JP:ja
ENV LC_ALL=ja_JP.UTF-8
ENV TERM xterm

RUN mkdir -p ~/ffmpeg_sources && \
    echo "/opt/vc/lib" > /etc/ld.so.conf.d/ffmpeg.conf && \
    echo "/usr/local/lib" >> /etc/ld.so.conf.d/ffmpeg.conf && \
    ldconfig

RUN mkdir -p /root/src
COPY requirements.txt /root/src

RUN pip install --upgrade pip
RUN pip install --upgrade setuptools
RUN pip install -r /root/src/requirements.txt

RUN set -x && \
    cd ~/ffmpeg_sources && \
    git -C fdk-aac pull 2> /dev/null || git clone --depth 1 https://github.com/mstorsjo/fdk-aac && \
    cd fdk-aac && \
    autoreconf -fiv && \
    ./configure \
    --disable-shared && \
    make -j $(grep cpu.cores /proc/cpuinfo | sort -u | sed 's/[^0-9]//g') && \
    make install

RUN set -x && \
    ldconfig && \
    cd ~/ffmpeg_sources && \
    git clone https://github.com/FFmpeg/FFmpeg --depth=1 -b n4.4.3 ffmpeg && \
    cd ffmpeg && \
    ./configure \
      --enable-gpl \
      --enable-version3 \
      --enable-nonfree \
      --enable-libmp3lame \
      --enable-libfdk-aac \
      --enable-libx264 \
      --enable-libx265 \
      --disable-ffplay \
      --disable-debug \
      --disable-doc && \
    make -j $(grep cpu.cores /proc/cpuinfo | sort -u | sed 's/[^0-9]//g') && \
    make install

COPY execron.sh /
COPY ncdlcron /etc/cron.d/ncdlcron
RUN chmod 0644 /etc/cron.d/ncdlcron
RUN /usr/bin/crontab /etc/cron.d/ncdlcron
WORKDIR /root/src
CMD ["/bin/bash", "/execron.sh"]
