PORTNAME=	ipacctd
PORTVERSION=	1.47
PORTREVISION=	3
CATEGORIES=	net-mgmt
MASTER_SITES=	LOCAL/skv

MAINTAINER=	ports@FreeBSD.org
COMMENT=	IP accounting using divert socket

LICENSE=	BSD2CLAUSE

USES=		uidfix
USE_RC_SUBR=	ipacctd

# 5BSD: upstream opens socket(PF_INET, SOCK_RAW, IPPROTO_DIVERT), which is
# pf's divert(4) (divert-packet rules); the PF_DIVERT (ipfw) patch is gone.

OPTIONS_DEFINE=	DOCS

post-extract:
	@${MV} ${WRKDIR}/${PORTNAME} ${WRKSRC}

post-install-DOCS-on:
	@${MKDIR} ${STAGEDIR}${DOCSDIR}/ru
	${INSTALL_DATA} ${WRKSRC}/README.ipacctd ${STAGEDIR}${DOCSDIR}/ru

.include <bsd.port.mk>
