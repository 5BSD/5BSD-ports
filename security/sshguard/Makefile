PORTNAME=	sshguard
PORTVERSION=	2.5.1
PORTREVISION=	3
PORTEPOCH=	1
CATEGORIES=	security
MASTER_SITES=	SF/sshguard/sshguard/${PORTVERSION}

MAINTAINER=	kevinz5000@gmail.com
COMMENT=	Protect hosts from brute-force attacks against SSH and other services
WWW=		https://www.sshguard.net/

LICENSE=	BSD2CLAUSE

USE_RC_SUBR=	sshguard

GNU_CONFIGURE=	yes

# 5BSD uses PF; do not install the other platform firewall scripts.
MAKE_ARGS+=	libexec_SCRIPTS=sshg-fw-pf

SUB_FILES=	pkg-message

post-patch:
	@${REINPLACE_CMD} -e 's|%PREFIX%|${PREFIX}|' \
		${WRKSRC}/doc/sshguard.8.rst
	@${REINPLACE_CMD} -e 's|/usr/local|${PREFIX}|' \
		${WRKSRC}/examples/sshguard.conf.sample

post-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/etc
	${INSTALL_DATA} ${WRKSRC}/examples/sshguard.conf.sample \
		${STAGEDIR}${PREFIX}/etc

.include <bsd.port.mk>
