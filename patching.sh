#!/bin/bash
#
# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/igorpecovnik/lib
#
#
# Source patching functions
#



# description, patch, direction-normal or reverse, section
patchme ()
{
if [ $3 == "reverse" ]; then
	if [ "$(patch --dry-run -t -p1 < $SRC/lib/patch/$4/$2 | grep Reversed)" != "" ]; then 
		display_alert "... $1 [\e[0;35m reverting patch \x1B[0m] " "$4" "info"
		patch --batch --silent -t -p1 < $SRC/lib/patch/$4/$2 > /dev/null 2>&1
	else
		display_alert "... $1 [\e[0;35m already reverted \x1B[0m] " "$4" "info"
	fi
else
	if [ "$(patch --batch -p1 -N < $SRC/lib/patch/$4/$2 | grep Skipping)" != "" ]; then 
		display_alert "... $1 already applied" "$4" "wrn"
	else
		display_alert "... $1" "$4" "info"
	fi
fi
}

addnewdevice()
{
if [ $3 == "kernel" ]; then
	if [ "$(cat arch/arm/boot/dts/Makefile | grep $2)" == "" ]; then
		display_alert "... adding $1" "kernel" "info"
		sed -i 's/sun7i-a20-bananapi.dtb \\/sun7i-a20-bananapi.dtb \\\n    '$2'.dtb \\/g' arch/arm/boot/dts/Makefile
		cp $SRC/lib/patch/devices/$2".dts" arch/arm/boot/dts/
	fi
else
	# add to uboot to , experimental
	if [ "$(cat $SOURCES/$BOOTSOURCE/arch/arm/dts/Makefile | grep $2)" == "" ]; then
		display_alert "... adding $1 to u-boot DTS" "kernel" "info"
		sed -i 's/sun7i-a20-bananapi.dtb \\/sun7i-a20-bananapi.dtb \\\n    '$2'.dtb \\/g' arch/arm/dts/Makefile
		cp $SRC/lib/patch/devices/$2".dts" $SOURCES/$BOOTSOURCE/arch/arm/dts
	fi
fi
}

patching_sources(){
#--------------------------------------------------------------------------------------------------------------------------------
# Patching kernel sources
#--------------------------------------------------------------------------------------------------------------------------------
cd $SOURCES/$BOOTSOURCE

# fix u-boot tag
if [[ $UBOOTTAG == "" ]] ; then
	git checkout $FORCE -q $BOOTDEFAULT
	else
	git checkout $FORCE -q $UBOOTTAG
fi

cd $SOURCES/$LINUXSOURCE


if [[ $KERNELTAG == "" ]] ; then KERNELTAG="$LINUXDEFAULT"; fi
# fix kernel tag
if [[ $BRANCH == "next" ]] ; then
		git checkout $FORCE -q $KERNELTAG
	else
		git checkout $FORCE -q $LINUXDEFAULT

fi

# What are we building
grab_kernel_version

display_alert "Patching" "kernel $VER" "info"

# this is for almost all sources
patchme "compiler bug" 					"compiler.patch" 				"reverse" "kernel"

# mainline
if [[ $BRANCH == "next" && ($LINUXCONFIG == *sunxi* || $LINUXCONFIG == *cubox*) ]] ; then
    rm -f drivers/leds/trigger/ledtrig-usbdev.c
	rm -f drivers/net/can/sun4i_can.c  
	rm -f Documentation/devicetree/bindings/net/can/sun4i_can.txt
	patchme "sun4i: spi: Allow transfers larger than FIFO size" "spi_allow_transfer_larger.patch" 		"default" "kernel"
	patchme "fix BRCMFMAC AP mode Banana & CT" 					"brcmfmac_ap_banana_ct.patch" 		"default" "kernel"
	patchme "deb packaging fix" 								"packaging-next.patch" 				"default" "kernel"
	patchme "Banana M2 support, LEDs" 							"Sinoviop-bananas-M2-R1-M1-fixes.patch" 	"default" "kernel"	
	patchme "Cubieboard2 double SD version" 					"support_for_second_mmc_cubieboard2.patch" 	"default" "kernel"
	patchme "Allwinner A10/A20 CAN Controller support" 			"allwinner-a10-a20-can-v8.patch" 	"default" "kernel"
	
	#patchme "Security System #0001" 	"0001-ARM-sun5i-dt-Add-Security-System-to-A10s-SoC-DTS.patch" "default" "kernel"
	#patchme "Security System #0002" 	"0002-ARM-sun6i-dt-Add-Security-System-to-A31-SoC-DTS.patch" "default" "kernel"
	#patchme "Security System #0003" 	"0003-ARM-sun4i-dt-Add-Security-System-to-A10-SoC-DTS.patch" "default" "kernel"
	#patchme "Security System #0004" 	"0004-ARM-sun7i-dt-Add-Security-System-to-A20-SoC-DTS.patch" "default" "kernel"
	#rm Documentation/devicetree/bindings/crypto/sun4i-ss.txt
	#patchme "Security System #0005" 	"0005-ARM-sun4i-dt-Add-DT-bindings-documentation-for-SUN4I.patch" "default" "kernel"
	#rm -r drivers/crypto/sunxi-ss/
	#patchme "Security System #0006" 	"0006-crypto-Add-Allwinner-Security-System-crypto-accelera.patch" "default" "kernel"
	#patchme "Security System #0007" 	"0007-MAINTAINERS-Add-myself-as-maintainer-of-Allwinner-Se.patch" "default" "kernel"
	#patchme "Security System #0008" 	"0008-crypto-sun4i-ss-support-the-Security-System-PRNG.patch" "default" "kernel"
	#patchme "Security System #0009 remove failed A31" 	"0009-a31_breaks.patch" "default" "kernel"
		
	# add r1 switch driver
	if [ "$(patch --dry-run -t -p1 < $SRC/lib/patch/kernel/bananapi-r1-4.x.patch | grep previ)" == "" ]; then
		rm -rf drivers/net/phy/b53/
		rm -f drivers/net/phy/swconfig.c
		rm -f drivers/net/phy/swconfig_leds.c
		rm -f include/linux/platform_data/b53.h
		rm -f include/linux/switch.h
		rm -f include/uapi/linux/switch.h 
		patch -p1 -f -s -m < $SRC/lib/patch/kernel/bananapi-r1-4.x.patch
	fi

	# add H3
	#display_alert "Patching" "Allwinner H3 support" "info"
	#rm -f drivers/clk/sunxi/clk-bus-gates.c
	#rm -f drivers/pinctrl/sunxi/pinctrl-sun8i-h3.c
	#rm -f arch/arm/boot/dts/sun8i-h3-orangepi-plus.dts
	#rm -f arch/arm/boot/dts/sun8i-h3.dtsi
	#for i in $SRC/lib/patch/kernel/h3*.patch; do patch -p1 -l -f -s < $i; done
	
	# Add new devices
	addnewdevice "Lamobo R1" 			"sun7i-a20-lamobo-r1"					"kernel"
	#addnewdevice "Orange PI" 			"sun7i-a20-orangepi"					"kernel"
	#addnewdevice "Orange PI mini" 		"sun7i-a20-orangepi-mini"				"kernel"
	#addnewdevice "PCDuino Nano3" 		"sun7i-a20-pcduino3-nano"				"kernel"
	addnewdevice "Bananapi M2 A31s" 	"sun6i-a31s-bananapi-m2"				"kernel"
	addnewdevice "Bananapi M1 Plus" 	"sun7i-a20-bananapi-m1-plus"			"kernel"
	addnewdevice "Bananapi R1" 			"sun7i-a20-bananapi-r1"					"kernel"
	
fi

if [[ $BOARD == udoo* ]] ; then
	# hard fixed DTS tree
	if [[ $BRANCH == "next" ]] ; then
		cp $SRC/lib/patch/misc/Makefile-udoo-only arch/arm/boot/dts/Makefile
		patchme "Install DTB in dedicated package" 				"packaging-next.patch" 			"default" "kernel"
		patchme "Upgrade to 4.2.1" 								"patch-4.2.1" 			"default" "kernel"
		patchme "Upgrade to 4.2.2" 								"patch-4.2.1-2" 			"default" "kernel"
		patchme "Upgrade to 4.2.3" 								"patch-4.2.2-3" 			"default" "kernel"
		patchme "Upgrade to 4.2.4" 								"patch-4.2.3-4" 			"default" "kernel"
		patchme "Upgrade to 4.2.5" 								"patch-4.2.4-5" 			"default" "kernel"
	else
	# 
	#patchme "remove strange DTBs from tree" 					"udoo_dtb.patch" 				"default" "kernel"
	#patchme "remove n/a v4l2-capture from Udoo DTS" 			"udoo_dts_fix.patch" 			"default" "kernel"
	# patchme "deb packaging fix" 								"packaging-udoo-fix.patch" 		"default" "kernel"
	# temp instead of this patch
	
	# Upgrade to 3.14.55 (until 34 auto)
	for (( c=28; c<=34; c++ ))
	do
		display_alert "Patching" "3.14.$c-$(( $c+1 ))" "info"
		wget wget -qO - "https://www.kernel.org/pub/linux/kernel/v3.x/incr/patch-3.14.$c-$(( $c+1 )).gz" | gzip -d | patch -p1 -l -f -s >/dev/null 2>&1     
	done
	
	patchme "Upgrade to 3.14.36" 								"neo-patch-3.14.35-36" 			"default" "kernel"
	patchme "Upgrade to 3.14.37" 								"neo-patch-3.14.36-37" 			"default" "kernel"
	patchme "Upgrade to 3.14.38" 								"neo-patch-3.14.37-38" 			"default" "kernel"
	patchme "Upgrade to 3.14.39" 								"neo-patch-3.14.38-39" 			"default" "kernel"
	for (( c=39; c<=55; c++ ))
	do
		display_alert "Patching" "3.14.$c-$(( $c+1 ))" "info"
		wget wget -qO - "https://www.kernel.org/pub/linux/kernel/v3.x/incr/patch-3.14.$c-$(( $c+1 )).gz" | gzip -d | patch -p1 -l -f -s >/dev/null 2>&1     
	done	
	cp $SRC/lib/patch/kernel/builddeb-fixed-udoo scripts/package/builddeb
	fi
fi


# sunxi 3.4 dan and me
if [[ $LINUXSOURCE == "linux-sunxi" ]] ; then
	rm drivers/spi/spi-sun7i.c
	rm -r drivers/net/wireless/ap6210/
	patchme "SPI functionality" 					"spi.patch" 								"default" "kernel"
	patchme "Debian packaging fix" 					"packaging-sunxi-fix.patch" 				"default" "kernel"
	patchme "Aufs3" 								"linux-sunxi-3.4.108-overlayfs.patch" 		"default" "kernel"
	patchme "More I2S and Spdif" 					"i2s_spdif_sunxi.patch" 					"default" "kernel"
	patchme "A fix for rt8192" 						"rt8192cu-missing-case.patch" 				"default" "kernel"
	#patchme "Upgrade to 3.4.109" 					"patch-3.4.108-109" 						"default" "kernel"
	
	# banana/orange gmac  
	if [[ $BOARD == banana* || $BOARD == orangepi* || $BOARD == lamobo* ]] ; then
		patchme "Bananapi/Orange/R1 gmac" 								"bananagmac.patch" 		"default" "kernel"
		patchme "Bananapi PRO wireless" 								"wireless-bananapro.patch" 		"default" "kernel"
	else
		patchme "Banana PI/ PRO / Orange / R1 gmac" 					"bananagmac.patch" 		"reverse" "kernel"
		patchme "Bananapi PRO wireless" 								"wireless-bananapro.patch" 		"reverse" "kernel"
	fi
fi

# sunxi 3.4 dev
if [[ $LINUXSOURCE == "linux-sunxi-dev" ]] ; then

	# remove files to patch clearly
	rm -f drivers/hwmon/a20-tp.c
	rm -f drivers/spi/spi-sun7i.c
	rm -rf drivers/net/wireless/ap6210/
	rm -rf firmware/ap6210/
	rm -f include/linux/compiler-gcc5.h
	rm -f Documentation/lzo.txt 
	rm -f net/ipv6/output_core.c	
	rm -f arch/arm/mach-pxa/pxa_cplds_irqs.c
	rm -rf fs/overlayfs
	rm -f Documentation/filesystems/overlayfs.txt
	rm -rf drivers/net/phy/b53/
	rm -rf include/uapi
	rm -f drivers/net/phy/swconfig.c
	rm -f drivers/net/phy/swconfig_leds.c
	rm -f include/linux/platform_data/b53.h
	
	patchme "Debian packaging fix" 						"dev-packaging.patch" 						"default" "kernel"
	patchme "Upgrade to 3.4.104" 						"patch-3.4.103-104" 						"default" "kernel"
	patchme "Upgrade to 3.4.105" 						"patch-3.4.104-105" 						"default" "kernel"
	patchme "Upgrade to 3.4.106" 						"patch-3.4.105-106" 						"default" "kernel"
	patchme "Upgrade to 3.4.107" 						"patch-3.4.106-107" 						"default" "kernel"
	patchme "Upgrade to 3.4.108" 						"patch-3.4.107-108" 						"default" "kernel"
	
	# RT patch. Disabled by default
	#patchme "RT Kernel 3.4.108" 						"patch-3.4.108-rt136.patch" 				"default" "kernel"	
	#patchme "Sunxi-Codec Low Latency" 					"sunxi-codec_LL.patch" 						"default" "kernel"	 
	#
	patchme "Upgrade to 3.4.109" 						"patch-3.4.108-109" 						"default" "kernel"
	patchme "Upgrade to 3.4.110" 						"patch-3.4.109-110" 						"default" "kernel"
	patchme "Aufs3" 									"linux-sunxi-3.4.108-overlayfs.patch" 		"default" "kernel"
	patchme "Standalone driver for the A20 Soc temp" 	"a20-temp.patch" 							"default" "kernel"
	patchme "SPI Sun7i functionality" 					"dev-spi-sun7i.patch" 						"default" "kernel"
	patchme "I2S driver" 								"dev-i2s-spdif.patch" 						"default" "kernel"
	patchme "Clustering" 								"clustering-patch-3.4-ja1.patch" 			"default" "kernel"
	patchme "AP6210 driver Cubietruck / Banana PRO" 	"ap6210_module.patch" 						"default" "kernel"
	
	patchme "Banana touch screen driver fix" 			"banana_touch_screen.patch" 				"default" "kernel"
	patchme "GPIO fix" 									"gpio.patch" 								"default" "kernel"
	
	patchme "A fix for rt8192" 							"rt8192cu-missing-case.patch" 				"default" "kernel"
	patchme "R1 switch driver" 							"dev-bananapi-r1.patch" 					"default" "kernel"
	patchme "Chip ID patch and MAC fixing" 				"dev-chip-id-and-gmac-fixing-mac.patch" 	"default" "kernel"

fi

# cubox / hummingboard 3.14
if [[ $LINUXSOURCE == linux-cubox ]] ; then
	patchme "SPI and I2C functionality" 						"hb-i2c-spi.patch" 				"default" "kernel"
	patchme "deb packaging fix" 								"packaging-cubox.patch" 				"default" "kernel"
	# Upgrade to 3.14.56
	for (( c=14; c<=55; c++ ))
	do
		display_alert "... upgrading" "3.14.$c-$(( $c+1 ))" "info"
		wget wget -qO - "https://www.kernel.org/pub/linux/kernel/v3.x/incr/patch-3.14.$c-$(( $c+1 )).gz" | gzip -d | patch -p1 -l -f -s >/dev/null 2>&1     
	done
	
fi

# cubox / hummingboard 3.14.54 new kernel
if [[ $LINUXSOURCE == linux-cubox-edge ]] ; then
	patchme "deb packaging fix" 								"packaging-cubox.patch" 				"default" "kernel"
	# Upgrade to 3.14.56
	for (( c=54; c<=55; c++ ))
	do
		display_alert "... upgrading" "3.14.$c-$(( $c+1 ))" "info"
		wget wget -qO - "https://www.kernel.org/pub/linux/kernel/v3.x/incr/patch-3.14.$c-$(( $c+1 )).gz" | gzip -d | patch -p1 -l -f -s >/dev/null 2>&1     
	done
	
fi

# linux allwinner legacy: H3, A80, ...
if [[ $LINUXSOURCE == "linux-allwinner" ]] ; then
	rm arch/arm/mach-sunxi/power/brom/mksunxichecksum.c
	patchme "Debian packaging fix" 					"allwinnner-packaging.patch" 				"default" "kernel"
	# http://moinejf.free.fr/opi2/
	patchme "Orangepi 2 compiler fix" 					"allwinner-h3-orange.patch" 				"default" "kernel"
	# Upgrades. Need fixing
#	for (( c=39; c<=40; c++ ))
#	do
#		display_alert "Patching" "3.14.$c-$(( $c+1 ))" "info"
#		wget wget -qO - "https://www.kernel.org/pub/linux/kernel/v3.x/incr/patch-3.4.$c-$(( $c+1 )).gz" | gzip -d | patch -p1 -l -f     
#	done
fi

# What are we building
grab_kernel_version

#--------------------------------------------------------------------------------------------------------------------------------
# Patching u-boot sources
#--------------------------------------------------------------------------------------------------------------------------------

cd $SOURCES/$BOOTSOURCE
display_alert "Patching" "u-boot $UBOOTTAG" "info"

if [[ $BOARD == "udoo" ]] ; then
	#patchme "Enabled Udoo boot script loading from ext2" 					"udoo-uboot-fatboot.patch" 		"default" "u-boot"
	# temp instead of this patch
	cp $SRC/lib/patch/u-boot/udoo.h include/configs/
fi

if [[ $BOARD == "udoo-neo" ]] ; then
    cp $SRC/lib/patch/u-boot/udoo_neo.h include/configs/
	# This enables loading boot.scr from / and /boot, fat and ext2
#	if [ "$(patch --dry-run -t -p1 < $SRC/lib/patch/udoo-neo_fat_and_ext_boot_script_load.patch | grep previ)" == "" ]; then
 #      		patch --batch -N -p1 < $SRC/lib/patch/udoo-neo_fat_and_ext_boot_script_load.patch
	fi
#fi
if [[ $LINUXCONFIG == *sun* ]] ; then
	rm -f configs/Lamobo_R1_defconfig configs/Awsom_defconfig arch/arm/dts/sun7i-a20-lamobo-r1.dts
	#rm -f configs/Bananapi_M2_defconfig arch/arm/dts/sun6i-a31s-bananapi-m2.dts
	patchme "Add Lamobo R1" 							"add-lamobo-r1-uboot.patch" 		"default" "u-boot"
	#patchme "Add Banana Pi M2 A31S" 					"bananam2-a31s.patch" 		"default" "u-boot"
	patchme "Add AW SOM" 								"add-awsom-uboot.patch" 			"default" "u-boot"
	patchme "Add Armbian boot splash" 					"sunxi-boot-splash.patch" 			"default" "u-boot"
	#patchme "Add overscan" 					"u-boot-overscan-sunxi.patch" 			"default" "u-boot"
	
	#optional, need to test more
	#patchme "Cubieboard2 second SD card" 					"second_sd_card_cubieboard2.patch" 			"default" "u-boot"	
		
		
	# Add new devices
	addnewdevice "Lamobo R1" 			"sun7i-a20-lamobo-r1"	"u-boot"
	
fi



#--------------------------------------------------------------------------------------------------------------------------------
# Patching other sources: FBTFT drivers, ...
#--------------------------------------------------------------------------------------------------------------------------------
cd $SOURCES/$MISC4_DIR
display_alert "Patching" "other sources" "info"

# add small TFT display support  
if [[ "$FBTFT" = "yes" && $BRANCH != "next" ]]; then
IFS='.' read -a array <<< "$VER"
cd $SOURCES/$MISC4_DIR
if (( "${array[0]}" == "3" )) && (( "${array[1]}" < "5" ))
then
	git checkout $FORCE -q 06f0bba152c036455ae76d26e612ff0e70a83a82
else
	git checkout $FORCE -q master
fi

if [[ $BOARD == banana* || $BOARD == orangepi* || $BOARD == lamobo* ]] ; then
patchme "DMA disable on FBTFT drivers" 					"bananafbtft.patch" 		"default" "misc"


else
patchme "DMA disable on FBTFT drivers" 					"bananafbtft.patch" 		"reverse" "misc"
fi

mkdir -p $SOURCES/$LINUXSOURCE/drivers/video/fbtft
mount --bind $SOURCES/$MISC4_DIR $SOURCES/$LINUXSOURCE/drivers/video/fbtft
cd $SOURCES/$LINUXSOURCE
patchme "small TFT display support" 					"small_lcd_drivers.patch" 		"default" "kernel"
#else
#patchme "small TFT display support" 					"small_lcd_drivers.patch" 		"reverse" "kernel"
#umount $SOURCES/$LINUXSOURCE/drivers/video/fbtft >/dev/null 2>&1
fi

# sleep 
sleep 2

}
