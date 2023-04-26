SHELL := /usr/bin/env bash
SRC = $(shell pwd)/src
CC = xcrun -sdk iphoneos clang
STRIP = strip
I_N_T = install_name_tool
CFLAGS += -I$(SRC) -I$(SRC)/include -flto=full
ifeq ($(ASAN),1)
CFLAGS += -DASAN
endif
ifeq ($(DEV_BUILD),1)
CFLAGS += -DDEV_BUILD
DEV_TARGETS += xpchook.dylib
endif
export SRC CC CFLAGS STRIP I_N_T

all: ramdisk.dmg

binpack.dmg: binpack.tar loader.dmg hook_all
	sudo rm -rf ./binpack.dmg binpack
	sudo tar --preserve-permissions -xf binpack.tar
	sudo chown $${UID}:$${GID} .
	sudo mv cores/binpack .
	sudo rm -rf binpack/usr/share cores
	sudo ln -sf /cores/jbloader binpack/usr/sbin/p1ctl
	sudo mkdir -p binpack/Applications
	sudo mkdir -p binpack/usr/lib
	sudo mkdir -p binpack/Library/LaunchDaemons
	sudo cp -a dropbear-plist/*.plist binpack/Library/LaunchDaemons
	sudo cp src/launchd_hook/rootlesshooks.dylib binpack/usr/lib
	sudo cp src/launchd_hook/libellekit.dylib binpack/usr/lib/libelegantlowlevelelements.dylib
	sudo cp loader.dmg binpack
	sudo chown -R 0:0 binpack
	hdiutil create -size 8m -layout NONE -format UDZO -imagekey zlib-level=9 -srcfolder ./binpack -volname palera1nfs -fs HFS+ ./binpack.dmg
	sudo rm -rf binpack

ramdisk.dmg: jbinit jbloader jb.dylib $(DEV_TARGETS)
	$(MAKE) -C $(SRC)
	rm -f ramdisk.dmg
	sudo rm -rf ramdisk
	mkdir -p ramdisk
	mkdir -p ramdisk/{usr/lib,sbin,jbin,dev}
	ln -s /jbin/jbloader ramdisk/sbin/launchd
	ln -s /sbin/launchd ramdisk/jbin/launchd
	mkdir -p ramdisk/usr/lib
	cp $(SRC)/jbinit/jbinit ramdisk/usr/lib/dyld
	cp $(SRC)/launchd_hook/jb.dylib $(SRC)/jbloader/jbloader ramdisk/jbin
	cp $(SRC)/launchd_hook/injector.dylib ramdisk/jbin
ifeq ($(DEV_BUILD),1)
	cp $(SRC)/jbloader/launchctl/tools/xpchook.dylib ramdisk/jbin
endif
ifeq ($(ASAN),1)
	cp $(shell xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/*//lib/darwin/libclang_rt.{asan,ubsan}_ios_dynamic.dylib ramdisk/jbin
endif
	sudo gchown -R 0:0 ramdisk
ifeq ($(ASAN),1)
	hdiutil create -size 8M -layout NONE -format UDRW -uid 0 -gid 0 -srcfolder ./ramdisk -fs HFS+ -volname palera1nrd ./ramdisk.dmg
else
	hdiutil create -size 512K -layout NONE -format UDRW -uid 0 -gid 0 -srcfolder ./ramdisk -fs HFS+ -volname palera1nrd ./ramdisk.dmg
endif

loader.dmg: palera1n.ipa
	rm -rf loader.dmg Payload
	unzip palera1n.ipa
	hdiutil create -size 2m -layout NONE -format ULFO -uid 0 -gid 0 -volname palera1nLoader -srcfolder ./Payload -fs HFS+ ./loader.dmg
	rm -rf Payload

$(SRC)/dyld_platform_test/dyld_platform_test:
	$(MAKE) -C $(SRC)/dyld_platform_test

dyld_platform_test: $(SRC)/dyld_platform_test/dyld_platform_test

xpchook.dylib:
	$(MAKE) -C src/jbloader xpchook.dylib

clean:
	rm -f jb.dylib ramdisk.dmg binpack.dmg src/launchctl/tools/xpchook.dylib src/launchd_hook/libellekit.dylib \
		src/jbinit/jbinit src/jbloader/jbloader src/launchd_hook/jb.dylib src/launchd_hook/injector.dylib \
		src/jbloader/create_fakefs_sh.c src/dyld_platform_test/dyld_platform_test src/launchd_hook/rootlesshooks.dylib
	sudo rm -rf ramdisk binpack cores
	rm -rf src/launchd_hook/ellekit/build src/launchd_hook/rootlesshooks/.theos
	find . -name '*.o' -delete
	rm -f ramdisk.img4

hook_all:
	$(MAKE) -C src/launchd_hook all

.PHONY: all clean jbinit jbloader jb.dylib dyld_platform_test xpchook.dylib binpack.dmg hook_all
