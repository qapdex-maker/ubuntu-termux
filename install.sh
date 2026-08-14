#!/data/data/com.termux/files/usr/bin/bash

# Enforce secure umask so files created (like startubuntu.sh and resolv.conf)
# are not writable by other local users on a multi-user environment.
umask 022

time1="$( date +"%r" )"

install1 () {
directory=ubuntu-fs
# Use supported, secure LTS release instead of unsupported, EOL 24.10 release
UBUNTU_VERSION='24.04.4'
if [ -d "$directory" ];then
first=1
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m Directory '%s' already exists. Skipping the download and the extraction.\n" "$directory"
elif [ -z "$(command -v proot)" ];then
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m proot is missing! Please install it by running: pkg install proot\n"
printf "\e[0m"
exit 1
elif [ -z "$(command -v wget)" ];then
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m wget is missing! Please install it by running: pkg install wget\n"
printf "\e[0m"
exit 1
fi
if [ "$first" != 1 ];then
# Determine architecture once for downloading and cache verification
ARCHITECTURE=$(dpkg --print-architecture)
case "$ARCHITECTURE" in
aarch64) ARCHITECTURE=arm64;;
arm) ARCHITECTURE=armhf;;
amd64|x86_64) ARCHITECTURE=amd64;;
*)
# Secure against printf format string vulnerabilities by passing ARCHITECTURE via %s
printf "\x1b[38;5;214m[%s]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Unknown architecture :- %s\n" "${time1}" "$ARCHITECTURE"
exit 1
;;
esac

# Performance/Security Optimization: Fetch expected SHA256 checksum from the remote server EXACTLY ONCE
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Fetching expected SHA256 checksum from remote server...\n"
EXPECTED_SHA256=$(wget -q -O- "https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/SHA256SUMS" | grep "ubuntu-base-${UBUNTU_VERSION}-base-${ARCHITECTURE}.tar.gz" | cut -d' ' -f1)

if [ -z "$EXPECTED_SHA256" ]; then
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Failed to retrieve remote SHA256 checksum. Please check your internet connection.\n"
    exit 1
fi

download_needed=1
if [ -f "ubuntu.tar.gz" ];then
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Existing ubuntu.tar.gz found. Verifying checksum to see if download can be skipped...\n"
    # Verify the archive locally in-memory using the pre-fetched EXPECTED_SHA256, avoiding a redundant network request
    if echo "$EXPECTED_SHA256  ubuntu.tar.gz" | sha256sum -c - >/dev/null 2>&1; then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Existing ubuntu.tar.gz is valid! Skipping download.\n"
        download_needed=0
    else
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m Existing ubuntu.tar.gz is invalid or incomplete. Attempting to resume download...\n"
    fi
fi

if [ "$download_needed" = 1 ];then
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Downloading the ubuntu rootfs, please wait...\n"

wget https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${ARCHITECTURE}.tar.gz -q --show-progress -O ubuntu.tar.gz
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Download complete!\n"

# Verify SHA256 checksum to protect against MITM / corruption (Sentinel security improvement)
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Verifying SHA256 checksum...\n"
if ! echo "$EXPECTED_SHA256  ubuntu.tar.gz" | sha256sum -c - >/dev/null 2>&1; then
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m Resumed download failed checksum validation. Deleting and performing fresh download...\n"
    rm -rf ubuntu.tar.gz
    # Fall back to a complete fresh download
    wget -q --show-progress "https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${ARCHITECTURE}.tar.gz" -O ubuntu.tar.gz
    printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Verifying SHA256 checksum of fresh download...\n"
    if ! echo "$EXPECTED_SHA256  ubuntu.tar.gz" | sha256sum -c - >/dev/null 2>&1; then
        printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m SHA256 checksum verification failed! The download may be corrupted or compromised.\n"
        rm -rf ubuntu.tar.gz
        exit 1
    fi
fi
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m SHA256 checksum verified successfully!\n"

fi

cur=`pwd`
mkdir -p $directory
cd $directory
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Decompressing the ubuntu rootfs, please wait...\n"
# Performance Optimization: Run the CPU-heavy decompression natively (outside of proot) and pipe the decompressed stream into proot.
# This avoids ptrace interception overhead for the decompression process, significantly speeding up extraction in PRoot.
gzip -dc "$cur/ubuntu.tar.gz" | proot --link2symlink tar -xf - --exclude='dev'||:
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m The ubuntu rootfs have been successfully decompressed!\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Fixing the resolv.conf, so that you have access to the internet\n"
printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" > etc/resolv.conf
stubs=()
stubs+=('usr/bin/groups')
for f in ${stubs[@]};do
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Writing stubs, please wait...\n"
echo -e "#!/bin/sh\nexit" > "$f"
done
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully wrote stubs!\n"
cd $cur

fi

mkdir -p ubuntu-binds
bin=startubuntu.sh
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Creating the start script, please wait...\n"
cat > $bin <<- EOM
#!/bin/bash
cd "\$(dirname "\$0")"
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
command="proot"
## uncomment following line if you are having FATAL: kernel too old message.
#command+=" -k 4.14.81"
command+=" --link2symlink"
command+=" -0"
command+=" -r $directory"
if [ -n "\$(ls -A ubuntu-binds)" ]; then
    for f in ubuntu-binds/* ;do
      [ -f "\$f" ] && . "\$f"
    done
fi
command+=" -b /dev"
command+=" -b /proc"
command+=" -b /sys"
command+=" -b ubuntu-fs/tmp:/dev/shm"
command+=" -b /data/data/com.termux"
command+=" -b //:/host-rootfs"
command+=" -b /sdcard"
command+=" -b /storage"
command+=" -b /mnt"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
com="\$@"
if [ -z "\$1" ] ;then
    exec \$command
else
    \$command -c "\$com"
fi
EOM
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m The start script has been successfully created!\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Fixing shebang of startubuntu.sh, please wait...\n"
termux-fix-shebang $bin
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully fixed shebang of startubuntu.sh! \n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Making startubuntu.sh executable please wait...\n"
chmod +x $bin
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully made startubuntu.sh executable\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Cleaning up please wait...\n"
rm ubuntu.tar.gz -rf
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m Successfully cleaned up!\n"
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m The installation has been completed! You can now launch Ubuntu with ./startubuntu.sh\n"
printf "\e[0m"

}
if [ "$1" = "-y" ] ;then
install1
elif [ "$1" = "" ] ;then
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;127m[QUESTION]:\e[0m \x1b[38;5;87m Do you want to install ubuntu-in-termux? [Y/n] "

read cmd1
# Treat empty inputs (pressing Enter) as default "Yes", and accept standard affirmative variations
if [ -z "$cmd1" ] || [ "$cmd1" = "y" ] || [ "$cmd1" = "Y" ] || [ "$cmd1" = "yes" ] || [ "$cmd1" = "Yes" ] || [ "$cmd1" = "YES" ] ;then
install1
else
printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Installation aborted by user.\n"
printf "\e[0m"
exit 1
fi
else
# Secure against printf format string vulnerabilities by passing user-supplied $1 via %s
printf "\x1b[38;5;214m[%s]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m Invalid option: '%s'. Use -y to bypass interactive confirmation.\n" "${time1}" "$1"
printf "\e[0m"
exit 1
fi
