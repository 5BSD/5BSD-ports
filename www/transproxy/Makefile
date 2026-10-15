PORTNAME=	transproxy
PORTVERSION=	1.6
PORTREVISION=	2
CATEGORIES=	www
MASTER_SITES=	SF

MAINTAINER=	ports@FreeBSD.org
COMMENT=	Transparent HTTP proxy for PF divert-to rules
WWW=		https://transproxy.sourceforge.net/

LICENSE=	BSD4CLAUSE # ish; 3 clauses but both advertising and promotion are there
LICENSE_FILE=	${WRKSRC}/COPYRIGHT

USES=		tar:tgz

USE_RC_SUBR=	tproxy

# 5BSD: no ipfw(8) or IPFilter.  The default (non-IPFILTER) build takes the
# original destination from getsockname(2), as with ipfw fwd; OpenBSD PF
# divert-to provides the same, e.g.
#   pass in on $int_if proto tcp to port www divert-to 127.0.0.1 port 8081

.include <bsd.port.mk>
