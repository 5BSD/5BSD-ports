PORTNAME=	nagios-pf-plugin
PORTVERSION=	0.1
PORTREVISION=	5
CATEGORIES=	net-mgmt

MAINTAINER=	rand@iteris.com
COMMENT=	Nagios plugin for checking PF
WWW=		https://github.com/kian/nagios-pf-plugin/

# 5BSD: base runs OpenBSD PF, so the plugin's native DIOCGETSTATUS and
# DIOCGETLIMIT ioctls work unchanged.

USE_GITHUB=	yes
GH_ACCOUNT=	kian
GH_TAGNAME=	2aba423

PLIST_FILES=	libexec/nagios/check_pf
SUB_FILES=	pkg-message

pre-install:
	@${MKDIR} ${STAGEDIR}${PREFIX}/libexec/nagios

.include <bsd.port.mk>
