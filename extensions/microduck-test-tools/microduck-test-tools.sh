# Rockchip factory stress-test tools (rockchip-test suite from the RK3566
# SDK external/rockchip-test, plus stressapptest). Enabled for FULL images.

add_packages_to_image memtester libaio1

# Runs after image apt packages, so libaio1 is already in place.
function post_install_kernel_debs__microduck_test_tools() {
	# stressapptest was removed from bookworm and the sid build needs the
	# t64 libaio; ship the last pre-t64 release (1.0.9-3, snapshot.debian.org).
	run_host_command_logged cp -v "${EXTENSION_DIR}/debs/stressapptest_1.0.9-3_arm64.deb" "${SDCARD}/tmp/"
	chroot_sdcard dpkg -i /tmp/stressapptest_1.0.9-3_arm64.deb
	run_host_command_logged rm -fv "${SDCARD}/tmp/stressapptest_1.0.9-3_arm64.deb"

	# Suite resolves paths relative to itself; /rockchip-test matches RK docs.
	run_host_command_logged cp -r "${EXTENSION_DIR}/rockchip-test" "${SDCARD}/rockchip-test"
}
