PORTNAME=	throttled
PORTVERSION=	0.5.2
CATEGORIES=	net
MASTER_SITES=	http://www.intrarts.com/Files/

MAINTAINER=	quest@mac.com
COMMENT=	Bandwidth shaping and QoS solution
WWW=		https://www.intrarts.com/throttledcli.html

LICENSE=	GPLv3

# 5BSD: base has no ipfw(8).  throttled reads packets from a divert socket,
# which pf's divert-packet can feed, but the installed throttled-startup and
# rc script configure and require ipfw.  Port the startup script to pf
# (divert-packet rules) and check the divert socket code before enabling.
BROKEN=		startup script configures ipfw divert rules; needs porting to pf divert-packet

USES=		gmake tar:tgz
USE_RC_SUBR=	${PORTNAME}
PLIST_FILES=	sbin/throttled sbin/throttled-startup

post-patch:
	@${REINPLACE_CMD} -e "s|/usr/local|${STAGEDIR}${PREFIX}|g" \
		${WRKSRC}/Makefile
	@${REINPLACE_CMD} -e "s|c++|${CXX}|;s|-O3|${CXXFLAGS}|" \
		${WRKSRC}/src/Makefile

.include <bsd.port.mk>
