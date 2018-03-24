# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
PYTHON_COMPAT=( python2_7 )

inherit systemd user toolchain-funcs python-any-r1

DESCRIPTION="An Open Source MQTT v3 Broker"
HOMEPAGE="http://mosquitto.org/"
SRC_URI="http://mosquitto.org/files/source/${P}.tar.gz"

LICENSE="EPL-1.0"
SLOT="0"
KEYWORDS="~amd64 ~arm ~x86"
IUSE="bridge examples +persistence +srv ssl tcpd test websockets"

REQUIRED_USE="test? ( bridge )"

RDEPEND="tcpd? ( sys-apps/tcp-wrappers )
	ssl? ( dev-libs/openssl:0= )"
DEPEND="${RDEPEND}
	${PYTHON_DEPS}
	srv? ( net-dns/c-ares )
	websockets? ( net-libs/libwebsockets )"

_emake() {
	LIBDIR=$(get_libdir)
	emake \
		CC="$(tc-getCC)" \
		LIB_SUFFIX="${LIBDIR:3}" \
		WITH_BRIDGE="$(usex bridge)" \
		WITH_PERSISTENCE="$(usex persistence)" \
		WITH_SRV="$(usex srv)" \
		WITH_TLS="$(usex ssl)" \
		WITH_WEBSOCKETS="$(usex websockets)" \
		WITH_WRAP="$(usex tcpd)" \
		"$@"
}

pkg_setup() {
	enewgroup mosquitto
	enewuser mosquitto -1 -1 -1 mosquitto
}

src_prepare() {
	if use persistence; then
		sed -i -e "/^#autosave_interval/s|^#||" \
			-e "s|^#persistence false$|persistence true|" \
			-e "/^#persistence_file/s|^#||" \
			-e "s|#persistence_location|persistence_location /var/lib/mosquitto/|" \
			mosquitto.conf || die
	fi

	# Remove prestripping
	sed -i -e 's/-s --strip-program=${CROSS_COMPILE}${STRIP}//'\
		client/Makefile lib/cpp/Makefile src/Makefile lib/Makefile || die

	python_setup
	python_fix_shebang test
	eapply_user
}

src_compile() {
	_emake
}

src_test() {
	_emake test
}

src_install() {
	_emake DESTDIR="${D}" prefix=/usr install
	keepdir /var/lib/mosquitto
	fowners mosquitto:mosquitto /var/lib/mosquitto
	dodoc readme.md CONTRIBUTING.md ChangeLog.txt
	doinitd "${FILESDIR}"/mosquitto
	insinto /etc/mosquitto
	doins mosquitto.conf
	systemd_dounit "${FILESDIR}/mosquitto.service"

	if use examples; then
		docompress -x "/usr/share/doc/${PF}/examples"
		docinto "/usr/share/doc/${PF}"
		doins -r examples
	fi
}

pkg_postinst() {
	elog ""
	elog "The Python module has been moved out of mosquitto."
	elog "See http://mosquitto.org/documentation/python/"
	elog ""
	elog "To start the mosquitto daemon at boot, add it to the default runlevel with:"
	elog ""
	elog "    rc-update add mosquitto default"
	elog "    or"
	elog "    systemctl enable mosquitto"
}