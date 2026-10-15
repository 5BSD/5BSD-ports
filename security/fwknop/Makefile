PORTNAME=	fwknop
PORTVERSION=	2.6.10
PORTREVISION=	6
CATEGORIES=	security
MASTER_SITES=	http://www.cipherdyne.org/fwknop/download/

MAINTAINER=	sean.greven@gmail.com
COMMENT=	SPA implementation for Linux and FreeBSD
WWW=		https://www.cipherdyne.org/fwknop/

LICENSE=	GPLv2

BUILD_DEPENDS=	wget:ftp/wget
RUN_DEPENDS=	wget:ftp/wget
LIB_DEPENDS+=	libassuan.so:security/libassuan

USES=		cpe libtool
USE_LDCONFIG=	yes
USE_RC_SUBR=	fwknopd

CPE_VENDOR=	cipherdyne
CONFLICTS_BUILD=	fwknop-2.6.8_*

GNU_CONFIGURE=	yes
GNU_CONFIGURE_MANPREFIX=${PREFIX}/share

INSTALL_TARGET=	install-strip
INFO=		libfko

# 5BSD: base has no ipfw(8); fwknopd always uses its PF backend, which
# manages rules in a "fwknop" anchor through pfctl(8) (OpenBSD PF syntax).
CONFIGURE_ARGS+=	--with-pf=/sbin/pfctl

OPTIONS_DEFINE=	GPGME

OPTIONS_DEFAULT=	GPGME

GPGME_DESC=	Build support for gpgme

GPGME_LIB_DEPENDS=	libgpgme.so:security/gpgme
GPGME_LIB_DEPENDS+=	libgpg-error.so:security/libgpg-error
GPGME_CONFIGURE_WITH=	gpgme

post-install:
	(cd ${STAGEDIR}${PREFIX}/etc/fwknop && ${MV} access.conf access.conf.sample)
	(cd ${STAGEDIR}${PREFIX}/etc/fwknop && ${MV} fwknopd.conf fwknopd.conf.sample)

.include <bsd.port.mk>
