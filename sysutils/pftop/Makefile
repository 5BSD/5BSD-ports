PORTNAME=	pftop
PORTVERSION=	0.13
CATEGORIES=	sysutils net
MASTER_SITES=	https://github.com/grembo/pftop/releases/download/${DISTVERSION}/

MAINTAINER=	grembo@FreeBSD.org
COMMENT=	Utility for real-time display of statistics for pf
WWW=		https://github.com/grembo/pftop/

LICENSE=	BSD2CLAUSE

# 5BSD: base runs OpenBSD PF.  pftop 0.13 is the FreeBSD fork that reads
# states, rules and labels through libpfctl (retired with FreeBSD pf), and
# its queue view uses ALTQ, which OpenBSD PF does not have.  It needs its
# OpenBSD ioctl backend (DIOCGETSTATES with struct pfsync_state, DIOCGETRULE,
# DIOCGETQUEUES/DIOCGETQSTATS) restored before it can build.  On 5BSD,
# "pfctl -ss", "pfctl -vsr" and "pfctl -vsq" give the same data meanwhile.
BROKEN=		needs its OpenBSD PF ioctl backend restored: this FreeBSD fork requires libpfctl

USES=		localbase uidfix

.include <bsd.port.options.mk>

MAKE_ARGS=	LOCALBASE="${PREFIX}" MANDIR=${PREFIX}/share/man/man

CFLAGS+=	-DHAVE_SNPRINTF=1 -DHAVE_VSNPRINTF=1

MAKE_ARGS+=	CSTD=gnu89

PLIST_FILES=	sbin/pftop \
		share/man/man8/pftop.8.gz

.include <bsd.port.mk>
