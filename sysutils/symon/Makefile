PORTNAME=	symon
DISTVERSION=	2.90
PORTREVISION=	4
CATEGORIES=	sysutils
MASTER_SITES=	https://wpd.home.xs4all.nl/symon/philes/

MAINTAINER=	jamie@catflap.org
COMMENT=	Performance and information monitoring tool
WWW=		https://wpd.home.xs4all.nl/symon/

LICENSE=	BSD2CLAUSE
LICENSE_FILE=	${WRKSRC}/LICENSE

USES=		perl5 shebangfix
USE_PERL5=	build

SHEBANG_FILES=	client/getsymonitem.pl

MAKE_ARGS=	EXADIR="etc" \
		LORDER=echo \
		MANDIR="share/man" \
		PREFIX="${STAGEDIR}${PREFIX}" \
		RRDDIR="${LOCALBASE}" \
		SYSCONFDIR="${PREFIX}/etc" \
		SUBDIR="lib ${SUBDIR} client" \
		TSORT=cat

MAKE_JOBS_UNSAFE=	yes

CFLAGS+=	-D_WANT_SEMUN

EXTRACT_AFTER_ARGS=	--strip-components 1 \
			--no-same-owner --no-same-permissions
SUB_FILES=	pkg-message

NO_WRKSUBDIR=	yes

USERS=		_symon
GROUPS=		_symon

PORTDOCS=	CHANGELOG HACKERS TODO

OPTIONS_DEFINE=		DOCS
OPTIONS_DEFAULT=	SYMON SYMUX
OPTIONS_MULTI=		MODULES
OPTIONS_MULTI_MODULES=	SYMON SYMUX
OPTIONS_SUB=		yes

MODULES_DESC=		Modules
SYMON_DESC=		Include symon(8) system monitor.
SYMUX_DESC=		Include symon stream multiplexer [symux(8)]

SYMON_VARS=		SUBDIR+=symon \
			USE_RC_SUBR+=symon
SYMUX_LIB_DEPENDS=	librrd.so:databases/rrdtool
SYMUX_VARS=		SUBDIR+=symux \
			USE_RC_SUBR+=symux

.include <bsd.port.pre.mk>

post-patch:
# We need to teach symon about mbstat changes/removal in r253351 and r253361.
	@${RM} ${WRKSRC}/platform/FreeBSD/sm_mbuf.c
# 5BSD: base runs OpenBSD PF, which keeps DIOCGETSTATUS (struct pf_status
# with counters, pcounters and bcounters), so the pf probe stays enabled.

do-install-DOCS-on:
	${MKDIR} ${STAGEDIR}${DOCSDIR}
	${INSTALL_DATA} ${PORTDOCS:S|^|${WRKSRC}/|} \
		${STAGEDIR}${DOCSDIR}

post-install-SYMON-on:
	${MV} ${STAGEDIR}${PREFIX}/etc/symon.conf \
		${STAGEDIR}${PREFIX}/etc/symon.conf.sample

post-install-SYMUX-on:
	${MV} ${STAGEDIR}${PREFIX}/etc/symux.conf \
		${STAGEDIR}${PREFIX}/etc/symux.conf.sample

.include <bsd.port.post.mk>
