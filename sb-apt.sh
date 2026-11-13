#!/bin/bash
set -e

SB_BASE_URL=http://$SB_API_KEY.debmirror.stablebuild.com

if [ -z "$SB_API_KEY" ]; then
    echo "Missing SB_API_KEY"
    exit 1
fi

if [ -z "$APT_PIN_DATE" ]; then
    echo "Missing APT_PIN_DATE, should match a tag from $SB_BASE_URL"
    exit 1
fi

UNAME=`uname -m`

IS_UBUNTU=0
IS_DEBIAN=0

if ls /etc/*release 1> /dev/null 2>&1; then
    DIST_NAME=$(cat /etc/*release | grep "^NAME=" | cut -d'=' -f2)

    if [[ $DIST_NAME == *"Ubuntu"* ]]; then
        IS_UBUNTU=1
    elif [[ $DIST_NAME == *"Debian"* ]]; then
        IS_DEBIAN=1
    fi
fi

if [[ $IS_UBUNTU -eq 0 && $IS_DEBIAN -eq 0 ]]; then
    echo "Could not determine OS. This script only supports Ubuntu and Debian."
    exit 1
fi

if [ "$1" == "load-apt-sources" ]; then

    LOAD_UBUNTU=0
    LOAD_UBUNTU_SRC=0
    LOAD_UBUNTU_BACKPORTS=0
    LOAD_DEADSNAKES=0
    LOAD_DOCKER_CE_UBUNTU=0
    LOAD_DOCKER_CE_DEBIAN=0
    LOAD_NVIDIA_CUDA=0
    LOAD_CHROMIUM=0
    LOAD_POSTGRES=0
    LOAD_UBUNTU_TOOLCHAIN_TEST=0
    LOAD_DEBIAN=0
    LOAD_DEBIAN_SRC=0
    LOAD_DEBIAN_BACKPORTS=0
    LOAD_DEBIAN_TESTING=0
    LOAD_ROS_ONE=0
    LOAD_ROS_TWO=0
    LOAD_QCOM_IOT=0

    while [[ $# -gt 0 ]]; do
        case $1 in
            ubuntu)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'ubuntu' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_UBUNTU=1
                shift # past argument
                ;;
            ubuntu-src)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'ubuntu-src' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_UBUNTU_SRC=1
                shift # past argument
                ;;
            ubuntu-backports)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'ubuntu-backports' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_UBUNTU_BACKPORTS=1
                shift # past argument
                ;;
            deadsnakes)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'deadsnakes' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_DEADSNAKES=1
                shift # past argument
                ;;
            docker-ce)
                if [[ $IS_UBUNTU -eq 1 ]]; then
                    LOAD_DOCKER_CE_UBUNTU=1
                elif [[ $IS_DEBIAN -eq 1 ]]; then
                    LOAD_DOCKER_CE_DEBIAN=1
                else
                    echo "'docker-ce' is only supported on Ubuntu or Debian"
                    exit 1
                fi
                shift # past argument
                ;;
            nvidia-cuda)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'nvidia-cuda' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_NVIDIA_CUDA=1
                shift # past argument
                ;;
            chromium)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'chromium' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_CHROMIUM=1
                shift # past argument
                ;;
            postgres)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'postgres' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_POSTGRES=1
                shift # past argument
                ;;
            ubuntu-toolchain-test)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'ubuntu-toolchain-test' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_UBUNTU_TOOLCHAIN_TEST=1
                shift # past argument
                ;;
            ros1)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'ros1' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_ROS_ONE=1
                shift # past argument
                ;;
            ros2)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'ros2' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_ROS_TWO=1
                shift # past argument
                ;;
            qcom-iot)
                if [[ $IS_UBUNTU -eq 0 ]]; then
                    echo "'qcom-iot' is only supported on Ubuntu"
                    exit 1
                fi
                LOAD_QCOM_IOT=1
                shift # past argument
                ;;
            debian)
                if [[ $IS_DEBIAN -eq 0 ]]; then
                    echo "'debian' is only supported on Debian"
                    exit 1
                fi
                LOAD_DEBIAN=1
                shift # past argument
                ;;
            debian-src)
                if [[ $IS_DEBIAN -eq 0 ]]; then
                    echo "'debian-src' is only supported on Debian"
                    exit 1
                fi
                LOAD_DEBIAN_SRC=1
                shift # past argument
                ;;
            debian-backports)
                if [[ $IS_DEBIAN -eq 0 ]]; then
                    echo "'debian-backports' is only supported on Debian"
                    exit 1
                fi
                LOAD_DEBIAN_BACKPORTS=1
                shift # past argument
                ;;
            debian-testing)
                if [[ $IS_DEBIAN -eq 0 ]]; then
                    echo "'debian-testing' is only supported on Debian"
                    exit 1
                fi
                LOAD_DEBIAN_TESTING=1
                shift # past argument
                ;;
            -*|--*)
                echo "Unknown option $1"
                exit 1
                ;;
            *)
                POSITIONAL_ARGS+=("$1") # save positional arg
                shift # past argument
                ;;
        esac
    done

    if [[ $LOAD_DEBIAN == 1 && $LOAD_DEBIAN_TESTING == 1 ]]; then
        echo "'debian' and 'debian-testing' cannot be loaded together"
        exit 1
    fi

    # Don't do valid until checks anymore, as our Release files will be outdated
    echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf.d/10-nocheckvalid

    if [[ $LOAD_UBUNTU == 1 ]]; then
        DIST_NAME=$(cat /etc/lsb-release | grep CODENAME | cut -d'=' -f2)
        # Ubuntu 24.04+ ships its upstream sources here
        rm -f /etc/apt/sources.list.d/ubuntu.sources

        if [[ "$UNAME" == aarch* ]] || [[ "$UNAME" == arm* ]]; then
            printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME main restricted \n\
deb $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-updates main restricted \n\
deb $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME universe \n\
deb $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-updates universe \n\
deb $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME multiverse \n\
deb $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-updates multiverse \n\
deb $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-security main restricted \n\
deb $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-security universe \n\
deb $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-security multiverse \n\
" > /etc/apt/sources.list
        else
            printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME main restricted \n\
deb $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-updates main restricted \n\
deb $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME universe \n\
deb $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-updates universe \n\
deb $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME multiverse \n\
deb $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-updates multiverse \n\
deb $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-security main restricted \n\
deb $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-security universe \n\
deb $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-security multiverse \n\
" > /etc/apt/sources.list
        fi
    fi

    if [[ $LOAD_UBUNTU_SRC == 1 ]]; then
        DIST_NAME=$(cat /etc/lsb-release | grep CODENAME | cut -d'=' -f2)

        if [[ "$UNAME" == aarch* ]] || [[ "$UNAME" == arm* ]]; then
            printf "\
deb-src $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME main restricted \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-updates main restricted \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME universe \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-updates universe \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME multiverse \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-updates multiverse \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-security main restricted \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-security universe \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-security multiverse \n\
" >> /etc/apt/sources.list
        else
            printf "\
deb-src $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME main restricted \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-updates main restricted \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME universe \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-updates universe \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME multiverse \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-updates multiverse \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-security main restricted \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-security universe \n\
deb-src $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-security multiverse \n\
" >> /etc/apt/sources.list
        fi
    fi

    if [[ $LOAD_UBUNTU_BACKPORTS == 1 ]]; then
        DIST_NAME=$(cat /etc/lsb-release | grep CODENAME | cut -d'=' -f2)

        if [[ "$UNAME" == aarch* ]] || [[ "$UNAME" == arm* ]]; then
            printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-backports main restricted universe multiverse \n\
" >> /etc/apt/sources.list
            if [[ $LOAD_UBUNTU_SRC == 1 ]]; then
                printf "\
deb-src $SB_BASE_URL/$APT_PIN_DATE/ports.ubuntu.com/ $DIST_NAME-backports main restricted universe multiverse \n\
" >> /etc/apt/sources.list
            fi
        else
            printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-backports main restricted universe multiverse \n\
" >> /etc/apt/sources.list
            if [[ $LOAD_UBUNTU_SRC == 1 ]]; then
                printf "\
deb-src $SB_BASE_URL/$APT_PIN_DATE/archive.ubuntu.com/ubuntu/ $DIST_NAME-backports main restricted universe multiverse \n\
" >> /etc/apt/sources.list
            fi
        fi
    fi

    if [[ $LOAD_DEBIAN == 1 ]]; then
        DIST_NAME=$(cat /etc/os-release | grep CODENAME | cut -d'=' -f2)
        # Debian 12+ ships its upstream sources here
        rm -f /etc/apt/sources.list.d/debian.sources

        printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian $DIST_NAME main
deb $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian-security $DIST_NAME-security main
deb $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian $DIST_NAME-updates main
" > /etc/apt/sources.list
    fi

    # Debian testing DIST_NAME varies with current unreleased DIST NAME
    # LOAD_DEBIAN and LOAD_DEBIAN_TESTING cannot work together
    if [[ $LOAD_DEBIAN_TESTING == 1 ]]; then
        rm -f /etc/apt/sources.list.d/debian.sources

        printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian testing main
deb $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian-security testing-security main
deb $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian testing-updates main
" > /etc/apt/sources.list
    fi

    if [[ $LOAD_DEADSNAKES == 1 ]]; then
        DIST_NAME=$(cat /etc/lsb-release | grep CODENAME | cut -d'=' -f2)

        apt update
        apt install -y gnupg
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BA6932366A755776

        printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/ppa.launchpad.net/deadsnakes/ppa/ubuntu/ $DIST_NAME main \n\
" >> /etc/apt/sources.list
    fi

    if [[ $LOAD_DOCKER_CE_UBUNTU == 1 ]]; then
        DIST_NAME=$(cat /etc/lsb-release | grep CODENAME | cut -d'=' -f2)

        apt update
        apt install -y gnupg
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7EA0A9C3F273FCD8

        printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/download.docker.com/linux/ubuntu/ $DIST_NAME stable \n\
" >> /etc/apt/sources.list
    fi

    if [[ $LOAD_DOCKER_CE_DEBIAN == 1 ]]; then
        DIST_NAME=$(cat /etc/os-release | grep CODENAME | cut -d'=' -f2)

        apt update
        apt install -y gnupg
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7EA0A9C3F273FCD8

        printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/download.docker.com/linux/debian/ $DIST_NAME stable \n\
" >> /etc/apt/sources.list
    fi

    if [[ $LOAD_NVIDIA_CUDA == 1 ]]; then
        VERSION=$(cat /etc/os-release | grep VERSION_ID | cut -d'=' -f2 | cut -d'"' -f2 | sed 's/\.//g')

        apt update
        apt install -y gnupg
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys A4B469963BF863CC

        if [[ "$UNAME" == aarch* ]] || [[ "$UNAME" == armv8* ]]; then
            printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/developer.download.nvidia.com/compute/cuda/repos/ubuntu$VERSION/sbsa / \n\
" > /etc/apt/sources.list.d/cuda.list
        elif [[ "$UNAME" == armv7* ]]; then
            echo "NVIDIA Cuda repository has no packages for ARMv7"
            exit 1
        else
            printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/developer.download.nvidia.com/compute/cuda/repos/ubuntu$VERSION/x86_64 / \n\
" > /etc/apt/sources.list.d/cuda.list
        fi
    fi

    if [[ $LOAD_CHROMIUM == 1 ]]; then
        DIST_NAME=$(cat /etc/debian_version | cut -d'/' -f1)

        apt update
        apt install -y gnupg
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 6ED0E7B82643E131
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 605C66F00D6C9793
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 648ACFD622F3D138

        printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian $DIST_NAME main \n\
deb $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian $DIST_NAME-updates main \n\
" > /etc/apt/sources.list.d/debian.list

        printf "\
Package: * \n\
Pin: release a=eoan \n\
Pin-Priority: 500 \n\
\n\
Package: * \n\
Pin: origin "snapshot.debian.org" \n\
Pin-Priority: 300 \n\
\n\
Package: chromium* libwebpmux3 \n\
Pin: origin "snapshot.debian.org" \n\
Pin-Priority: 700 \n\
" > /etc/apt/preferences.d/chromium.pref
    fi

    if [[ $LOAD_POSTGRES == 1 ]]; then
        DIST_NAME=$(cat /etc/lsb-release | grep CODENAME | cut -d'=' -f2)

        apt update
        apt install -y gnupg
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7FCC7D46ACCC4CF8

        printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/apt.postgresql.org/pub/repos/apt $DIST_NAME-pgdg main \n\
" >> /etc/apt/sources.list
    fi

    if [[ $LOAD_UBUNTU_TOOLCHAIN_TEST == 1 ]]; then
        DIST_NAME=$(cat /etc/lsb-release | grep CODENAME | cut -d'=' -f2)

        apt update
        apt install -y gnupg
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 1E9377A2BA9EF27F

        printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu $DIST_NAME main \n\
" >> /etc/apt/sources.list
    fi

    if [[ $LOAD_ROS_ONE == 1 || $LOAD_ROS_TWO == 1 ]]; then
        DIST_NAME=$(cat /etc/lsb-release | grep CODENAME | cut -d'=' -f2)

        apt update
        apt install -y gnupg

        echo "-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1

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
=9IZg
-----END PGP PUBLIC KEY BLOCK-----" | apt-key add -

        if [[ $LOAD_ROS_ONE == 1 ]]; then
            if [[ $DIST_NAME != "focal" ]]; then
                echo "'ros1' is only supported on Ubuntu 20.04 (focal)"
                exit 1
            fi

            printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/packages.ros.org/ros/ubuntu/ $DIST_NAME main \n\
" >> /etc/apt/sources.list
        fi

        if [[ $LOAD_ROS_TWO == 1 ]]; then
            printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/packages.ros.org/ros2/ubuntu/ $DIST_NAME main \n\
" >> /etc/apt/sources.list
        fi
    fi

    if [[ $LOAD_QCOM_IOT == 1 ]]; then
        DIST_NAME=$(cat /etc/lsb-release | grep CODENAME | cut -d'=' -f2)

        apt update
        apt install -y gnupg
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 1C70EB0C444248D7

        printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/ppa.launchpadcontent.net/ubuntu-qcom-iot/qcom-ppa/ubuntu $DIST_NAME main \n\
" >> /etc/apt/sources.list
    fi

    if [[ $LOAD_DEBIAN_SRC == 1 ]]; then
        DIST_NAME=$(cat /etc/os-release | grep CODENAME | cut -d'=' -f2)

        printf "\
deb-src $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian $DIST_NAME main
deb-src $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian-security $DIST_NAME-security main
deb-src $SB_BASE_URL/$APT_PIN_DATE/deb.debian.org/debian $DIST_NAME-updates main
" >> /etc/apt/sources.list
    fi

    if [[ $LOAD_DEBIAN_BACKPORTS == 1 ]]; then
        DIST_NAME=$(cat /etc/os-release | grep CODENAME | cut -d'=' -f2)

        DEBIAN_BACKPORTS_HOST=deb.debian.org
        if [[ $DIST_NAME == bullseye ]]; then
            # bullseye-backports mirrored from archive.debian.org
            DEBIAN_BACKPORTS_HOST=archive.debian.org
        fi

        printf "\
deb $SB_BASE_URL/$APT_PIN_DATE/$DEBIAN_BACKPORTS_HOST/debian $DIST_NAME-backports main
" >> /etc/apt/sources.list

        if [[ $LOAD_DEBIAN_SRC == 1 ]]; then
            printf "\
deb-src $SB_BASE_URL/$APT_PIN_DATE/$DEBIAN_BACKPORTS_HOST/debian $DIST_NAME-backports main
" >> /etc/apt/sources.list
        fi
    fi

    UNPINNED_SOURCES=$(grep -L "$SB_BASE_URL" /etc/apt/sources.list.d/* 2>/dev/null || true)
    if [ -n "$UNPINNED_SOURCES" ]; then
        echo "WARNING: these apt sources don't use the StableBuild mirror, so their packages are not pinned to $APT_PIN_DATE:" >&2
        echo "$UNPINNED_SOURCES" >&2
    fi

elif [ "$1" == "install-node-js" ]; then

    WGET_CLI=$(which wget || true)
    if [ ! -x "$WGET_CLI" ]; then
        echo "Cannot find 'wget' in your PATH. Install wget via 'apt update && apt install -y wget'"
        exit 1
    fi

    NODE_MAIN_VERSION=$(echo "$2" | cut -d "." -f 1)
    echo "Main version: $NODE_MAIN_VERSION"

    if [[ "$UNAME" == aarch* ]] || [[ "$UNAME" == armv8* ]]; then
        ARCH=arm64
    elif [[ "$UNAME" == armv7* ]]; then
        echo "Nodesource repository has no packages for ARMv7"
        exit 1
    else
        ARCH=amd64
    fi

    wget -O /tmp/nodejs.deb $SB_BASE_URL/$APT_PIN_DATE/deb.nodesource.com/node_$NODE_MAIN_VERSION.x/pool/main/n/nodejs/nodejs_$2-1nodesource1_$ARCH.deb
    dpkg -i /tmp/nodejs.deb
    rm /tmp/nodejs.deb

else
    echo "Unknown command: $1, valid commands are: 'load-apt-sources', 'install-node-js'"
    exit 1
fi
