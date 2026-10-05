PORTNAME=	5bsd-instruments
DISTVERSION=	0.3.9
CATEGORIES=	sysutils
MASTER_SITES=	https://github.com/5BSD/5BSD-ports/releases/download/toolkit-20261004/:toolkit \
		https://pub.dev/api/archives/:pub \
		https://storage.googleapis.com/flutter_infra_release/flutter/fonts/3012db47f3130e62f7cc0beabff968a33cbec8d8/:fonts
DISTNAME=	5bsd-flutter-eb529d2bebb5
DISTFILES=	${DISTNAME}.tar.xz:toolkit \
		5bsd-instruments-system-sources-20261005.tar.xz:toolkit \
		fonts.zip:fonts
DIST_SUBDIR=	5bsd-toolkit
EXTRACT_ONLY=	${DISTNAME}.tar.xz 5bsd-instruments-system-sources-20261005.tar.xz

MAINTAINER=	kory@5bsd.org
COMMENT=	5BSD system instruments and BSDTrace recording GUI
WWW=		https://github.com/5BSD/5BSD-ports
LICENSE=	BSD3CLAUSE APACHE20 CDDL
LICENSE_COMB=	multi
LICENSE_FILE_BSD3CLAUSE=	${WRKSRC}/LICENSE
LICENSE_FILE_CDDL=	${FILESDIR}/LICENSE.CDDL

ONLY_FOR_ARCHS=	amd64
BUILD_DEPENDS=	dart=3.13.5:lang/dart \
		flutter-engine=0.1.0:x11-toolkits/flutter-engine
RUN_DEPENDS=	flutter-engine=0.1.0:x11-toolkits/flutter-engine
USES=		compiler:c++20-lang gnome pkgconfig python tar:xz
USE_GNOME=	gtk30

# The engine and SDK overrides support building against staged packages.
# Installed binaries always use LOCALBASE for their final engine rpath.
DART_CMD?=	${LOCALBASE}/bin/dart
ENGINE_PREFIX?=	${LOCALBASE}
_BUNDLE_SEQUENCE=202610050002
_PUB_PACKAGES=	characters-1.4.1 collection-1.19.1 material_color_utilities-0.13.0 \
		meta-1.18.3 vector_math-2.4.0
.for package in ${_PUB_PACKAGES}
DISTFILES+=	${package}.tar.gz:pub
.endfor

SUB_FILES=	5bsd-instruments-register pkg-message
SUB_LIST=	VERSION=${DISTVERSION} SEQUENCE=${_BUNDLE_SEQUENCE} \
		PYTHON_CMD=${PYTHON_CMD}

post-extract:
	${MKDIR} ${WRKDIR}/pub-cache/hosted-hashes/pub.dev
.for package in ${_PUB_PACKAGES}
	${MKDIR} ${WRKDIR}/pub-cache/hosted/pub.dev/${package}
	${TAR} -xf ${DISTDIR}/${DIST_SUBDIR}/${package}.tar.gz -C ${WRKDIR}/pub-cache/hosted/pub.dev/${package}
	${SHA256} -q ${DISTDIR}/${DIST_SUBDIR}/${package}.tar.gz > ${WRKDIR}/pub-cache/hosted-hashes/pub.dev/${package}.sha256
.endfor

do-build:
	cd ${WRKSRC} && ${SETENV} PUB_CACHE=${WRKDIR}/pub-cache ${PYTHON_CMD} tools/5bsd/build_app.py \
		--dart ${DART_CMD} --engine-prefix ${ENGINE_PREFIX} --engine-runtime-prefix ${LOCALBASE} \
		--release --binary-name 5bsd-instruments --offline \
		--font-archive ${DISTDIR}/${DIST_SUBDIR}/fonts.zip \
		--system-source ${WRKDIR}/5bsd-instruments-system-sources-20261005 \
		--output ${WRKDIR}/runtime
	${RM} -r ${WRKDIR}/Instruments.cap
	${PYTHON_CMD} ${FILESDIR}/stage-cap.py ${WRKSRC} ${WRKDIR}/runtime ${WRKDIR}/Instruments.cap ${DISTVERSION} ${_BUNDLE_SEQUENCE}
	${INSTALL_DATA} ${FILESDIR}/LICENSE.CDDL ${WRKDIR}/Instruments.cap/Shared/licenses/CDDL.txt

do-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/libexec/5bsd-instruments
	${CP} -R ${WRKDIR}/Instruments.cap ${STAGEDIR}${PREFIX}/libexec/5bsd-instruments/
	${INSTALL_PROGRAM} ${WRKDIR}/runtime/5bsd-instruments-launch ${STAGEDIR}${PREFIX}/bin/5bsd-instruments
	${INSTALL_SCRIPT} ${WRKDIR}/5bsd-instruments-register ${STAGEDIR}${PREFIX}/sbin/
	${MKDIR} ${STAGEDIR}${PREFIX}/share/applications ${STAGEDIR}${PREFIX}/share/icons/hicolor/scalable/apps
	${INSTALL_DATA} ${FILESDIR}/org.fivebsd.Instruments.desktop ${STAGEDIR}${PREFIX}/share/applications/
	${INSTALL_DATA} ${WRKSRC}/examples/5bsd_desktop/assets/org.fivebsd.Instruments.svg ${STAGEDIR}${PREFIX}/share/icons/hicolor/scalable/apps/

do-test:
	${PYTHON_CMD} ${FILESDIR}/test-registration.py ${FILESDIR}/5bsd-instruments-register.in ${WRKDIR}/Instruments.cap

.include <bsd.port.mk>
