#!/usr/bin/env bash

set -euo pipefail

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "${SCRIPT}")
KERNEL="4.20.0-sound-40"
CLEAR="clear"
PARAMETER="${1:-}"
TAB=" "
GRUB_CFG=$(find /boot -name 'grub.cfg'|head -n1)

function spinner {
pid=$!
if [ ! -z "${PARAMETER}" ] && [ "${PARAMETER}" == "-v" ]; then
	spin=''
else
	spin='-\|/'
fi

i=0
while kill -0 $pid 2>/dev/null
do
	i=$(( (i+1) %4 ))
	printf "\r${spin:$i:1}"
	sleep .1
done
}

function silent {
if [ ! -z "${PARAMETER}" ] && [ "${PARAMETER}" == "-v" ]; then
	"${@}"
else
	"${@}" > /dev/null 2>&1
fi
}

function check_root {
if [ "${EUID}" -ne 0 ]; then
        printf "${TAB} This script is running as ${USER}, please run as root instead\n"
        exit 1
fi
}

function reboot_required {
if [ ! -z "${PARAMETER}" ] && [ "${PARAMETER}" == "-v" ]; then
	echo
else
	"${CLEAR}"
fi
printf "Finished !"
printf "${TAB} A reboot is required, do you want to reboot now or later ?\n"
PS3='Enter: '
echo
options=("Reboot now" "Reboot later")
select opt in "${options[@]}"
do
case "${opt}" in
	"Reboot now")
	REBOOT="yes"
	break
	;;
	"Reboot later")
	REBOOT="no"
	break
	;;
	*) echo invalid option;;
esac
done
if [ ! -z "${PARAMETER}" ] && [ "${PARAMETER}" == "-v" ]; then
	echo
else
	"${CLEAR}"
fi
echo
printf "${TAB} Remember to:\n"
printf "${TAB} -  Choose the right kernel (${KERNEL}) in grub at boot-time\n"
printf "${TAB} -  Run a GUI (like pavucontrol) to set the default soundcard output to \"Speaker\" instead of \"Headphones\"\n"
printf "${TAB} -  Reboot again\n"
if [ "${REBOOT}" == "no" ]; then
	sync
	echo
	printf "${TAB} Exiting script ...\n"
	exit 0
elif [ "${REBOOT}" == "yes" ]; then
	echo
	sync
	sleep 1
	read -p "${TAB} Press enter to continue rebooting ..."
	reboot
fi
}

function extract_tar {
if [ ! -z "${PARAMETER}" ] && [ "${PARAMETER}" == "-v" ]; then
	echo
else
	"${CLEAR}"
fi
printf "${TAB} Extracting kernel, initramfs, kernel-modules and ucm-files ..."
silent pushd /
silent tar xpvJf "${SCRIPTPATH}"/kernel-"${KERNEL}".tar.xz boot usr lib/modules lib/firmware/brcm/BCM43341B0.hcd &
spinner
silent popd
}

function generate_initramfs {
if [ ! -z "${PARAMETER}" ] && [ "${PARAMETER}" == "-v" ]; then
	echo
else
	"${CLEAR}"
fi
printf "${TAB} Generating initramfs (this may take a while) ..."
if [ $(command -v update-initramfs) ]; then
	silent update-initramfs -c -k "${KERNEL}" &
	spinner
elif [ $(command -v dracut) ]; then
	silent dracut -fv /boot/initramfs-"${KERNEL}".img "${KERNEL}" &
	spinner
elif [ $(command -v mkinitcpio) ]; then
	silent mkinitcpio -k "${KERNEL}" -c /etc/mkinitcpio.conf -g /boot/initramfs-"${KERNEL}".img &
	spinner
fi
}

function update_grub {
if [ ! -z "${PARAMETER}" ] && [ "${PARAMETER}" == "-v" ]; then
	echo
else
	"${CLEAR}"
fi
printf "${TAB} Updating grub ..."
if [ ! $(command -v update-grub) ]; then
	if [ $(command -v grub2-mkconfig) ]; then
	silent grub2-mkconfig -o "${GRUB_CFG}" &
	spinner
	elif [ $(command -v grub-mkconfig) ]; then
	silent grub-mkconfig -o "${GRUB_CFG}" &
	spinner
	fi
else
	silent update-grub &
	spinner
fi
}

check_root
extract_tar
generate_initramfs
update_grub
reboot_required

exit 0
