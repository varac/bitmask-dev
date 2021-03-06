# This makefile should be called from the topmost bitmask folder
#
OSX_RES = dist/Bitmask.app/Contents/Resources
OSX_CON = dist/Bitmask.app/Contents/MacOS
OSX_CERT = "Developer ID Installer: LEAP Encryption Access Project"


default:
	echo "enter 'make bundle or make bundle_osx'"

bundle: bundle_clean
	pyinstaller -y pkg/pyinst/app.spec
	cp $(VIRTUAL_ENV)/lib/python2.7/site-packages/_scrypt.so $(DIST)
	cp src/leap/bitmask/core/bitmaskd.tac $(DIST)
	mkdir -p $(DIST)/leap
	# if you find yourself puzzled becase the following files are not found in your
	# virtualenv, make sure that you're installing the packages from wheels and not eggs.
	mkdir -p $(DIST)/leap/soledad/client/_db
	cp $(VIRTUAL_ENV)/lib/python2.7/site-packages/leap/soledad/client/_db/dbschema.sql $(DIST)/leap/soledad/client/_db/
	cp $(VIRTUAL_ENV)/lib/python2.7/site-packages/leap/common/cacert.pem $(DIST)/
	cp -r $(VIRTUAL_ENV)/lib/python2.7/site-packages/leap/bitmask_js  $(DIST)/leap/
	cp -r $(VIRTUAL_ENV)/lib/python2.7/site-packages/leap/pixelated_www  $(DIST)/leap/
	echo `git describe` > $(DIST)/version
	mv $(DIST) _bundlelib && mkdir $(DIST_VERSION) && mv _bundlelib $(DIST_VERSION)/lib/
	cd pkg/launcher && make
	cp release-notes.rst $(DIST_VERSION)
	cp pkg/launcher/bitmask $(DIST_VERSION)

bundle_linux_gpg:
	# TODO build it in a docker container!
	mkdir -p $(DIST_VERSION)/apps/mail
	# this is /usr/bin/gpg1 in debian stretch 
	cp /usr/bin/gpg $(DIST_VERSION)/apps/mail/gpg
	# workaround for missing libreadline.so.6 in fresh ubuntu
	patchelf --set-rpath '.' $(DIST_VERSION)/apps/mail/gpg
	cp /lib/x86_64-linux-gnu/libusb-0.1.so.4 $(DIST_VERSION)/lib

bundle_linux_vpn:
	mkdir -p $(DIST_VERSION)/apps/vpn
	# TODO verify signature
	wget https://downloads.leap.se/thirdparty/linux/openvpn/openvpn -O $(DIST_VERSION)/apps/vpn/openvpn.leap

bundle_linux_helpers:
	mkdir -p $(DIST_VERSION)/apps/helpers
	cp src/leap/bitmask/vpn/helpers/linux/bitmask-root $(DIST_VERSION)/apps/helpers/
	cp src/leap/bitmask/vpn/helpers/linux/se.leap.bitmask.bundle.policy $(DIST_VERSION)/apps/helpers/
	cp /usr/lib/x86_64-linux-gnu/mesa/libGL.so.1.2.0 $(DIST_VERSION)/lib/libGL.so.1 || echo "libGL version not found"

bundle_osx_helpers:
	mkdir -p $(DIST_VERSION)/apps/helpers
	cp src/leap/bitmask/vpn/helpers/osx/bitmask-helper $(DIST_VERSION)/apps/helpers/
	cp src/leap/bitmask/vpn/helpers/osx/bitmask.pf.conf $(DIST_VERSION)/apps/helpers/
	cp pkg/osx/scripts/se.leap.bitmask-helper.plist $(DIST_VERSION)/apps/helpers/
	cp -r pkg/osx/daemon $(DIST_VERSION)/apps/helpers/
	cp -r pkg/osx/openvpn $(DIST_VERSION)/apps/helpers/

bundle_osx_missing:
	# relink _scrypt, it's linked against brew openssl!
	install_name_tool -change /usr/local/opt/openssl/lib/libcrypto.1.0.0.dylib  "@loader_path/libcrypto.1.0.0.dylib" $(DIST_VERSION)/lib/_scrypt.so
	cp $(DIST_VERSION)/lib/_scrypt.so $(OSX_CON)/
	cp $(DIST_VERSION)/lib/bitmaskd.tac $(OSX_CON)/
	cp $(DIST_VERSION)/lib/version $(OSX_CON)/
	cp -r $(DIST_VERSION)/lib/leap $(OSX_CON)/
	mv dist/Bitmask.app/Contents/MacOS/bitmask $(OSX_CON)/bitmask-app
	cp pkg/osx/bitmask-wrapper $(OSX_CON)/bitmask
	mkdir -p $(OSX_RES)/bitmask-helper
	cp -r $(DIST_VERSION)/apps/helpers/bitmask-helper $(OSX_RES)/bitmask-helper/
	cp -r $(DIST_VERSION)/apps/helpers/bitmask.pf.conf $(OSX_RES)/bitmask-helper/
	cp -r $(DIST_VERSION)/apps/helpers/daemon/daemon.py $(OSX_RES)/bitmask-helper/
	cp -r $(DIST_VERSION)/apps/helpers/openvpn/* $(OSX_RES)/
	wget https://downloads.leap.se/thirdparty/osx/openvpn/openvpn -O $(OSX_RES)/openvpn.leap
	chmod +x $(OSX_RES)/openvpn.leap

bundle_osx_pkg:
	pkg/osx/quickpkg --output dist/Bitmask-$(NEXT_VERSION)_pre.pkg --scripts pkg/osx/scripts/ dist/Bitmask.app/
	productsign --sign $(OSX_CERT) dist/Bitmask-$(NEXT_VERSION)_pre.pkg dist/Bitmask-$(NEXT_VERSION).pkg


bundle_linux: bundle bundle_linux_gpg bundle_linux_vpn bundle_linux_helpers

bundle_osx: bundle bundle_osx_helpers bundle_osx_missing bundle_osx_pkg

bundle_win:
	pyinstaller -y pkg/pyinst/app.spec
	cp ${VIRTUAL_ENV}/Lib/site-packages/_scrypt.pyd $(DIST)
	cp ${VIRTUAL_ENV}/Lib/site-packages/zmq/libzmq.pyd $(DIST)
	cp src/leap/bitmask/core/bitmaskd.tac $(DIST)

bundle_tar:
	cd dist/ && tar cvzf Bitmask.$(NEXT_VERSION).tar.gz bitmask-$(NEXT_VERSION)

bundle_sign:
	gpg2 -a --sign --detach-sign dist/Bitmask.$(NEXT_VERSION).tar.gz 

bundle_upload:
	rsync --rsh='ssh' -avztlpog --progress --partial dist/Bitmask.$(NEXT_VERSION).* downloads.leap.se:./

bundle_clean:
	rm -rf "dist" "build"
