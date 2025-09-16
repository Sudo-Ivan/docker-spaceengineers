FROM archlinux:latest

WORKDIR /root

ENV WINEARCH=win64
ENV WINEDEBUG=-all
ENV WINEPREFIX=/root/server

RUN \
  # Initialize pacman keyring
  pacman-key --init && \
  pacman-key --populate archlinux && \
  # Enable multilib repository for 32-bit packages
  echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf && \
  # Update system and install base packages
  pacman -Syu --noconfirm && \
  pacman -S --noconfirm base-devel git wget curl

RUN \
  # Install wine and dependencies
  pacman -S --noconfirm \
  wine \
  wine-gecko \
  wine-mono \
  xorg-server-xvfb \
  cabextract \
  winetricks \
  inetutils

RUN \
  # Install steamcmd from AUR
  useradd -m aur && \
  echo "aur ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
  su - aur -c "git clone https://aur.archlinux.org/steamcmd.git && cd steamcmd && makepkg -si --noconfirm" && \
  userdel -r aur && \
  sed -i '/aur ALL/d' /etc/sudoers 

# Winetricks (This block uses most of the build time)
COPY winetricks.sh /root/
RUN \
  /root/winetricks.sh && \
  rm -f /root/winetricks.sh && \
  # Clean package cache to reduce docker size
  pacman -Scc --noconfirm && \
  rm -rf /var/cache/pacman/pkg/*

COPY healthcheck.sh /root/
HEALTHCHECK --interval=60s --timeout=60s --start-period=600s --retries=3 CMD [ "/root/healthcheck.sh" ]

COPY entrypoint.sh /root/
ENTRYPOINT /root/entrypoint.sh