PORTNAME=	5bsd-imager
DISTVERSION=	0.2.0
CATEGORIES=	sysutils
MASTER_SITES=	https://github.com/5BSD/5BSD-ports/releases/download/toolkit-20261004/:toolkit \
		https://pub.dev/api/archives/:pub \
		https://storage.googleapis.com/flutter_infra_release/flutter/fonts/3012db47f3130e62f7cc0beabff968a33cbec8d8/:fonts
DISTNAME=	5bsd-flutter-eb529d2bebb5
DISTFILES=	${DISTNAME}.tar.xz:toolkit fonts.zip:fonts
DIST_SUBDIR=	5bsd-toolkit
EXTRACT_ONLY=	${DISTNAME}.tar.xz

MAINTAINER=	kory@5bsd.org
COMMENT=	Native 5BSD USB image writer with read-back verification
WWW=		https://github.com/5BSD/5BSD-ports

LICENSE=	BSD3CLAUSE APACHE20 MIT
LICENSE_COMB=	multi
LICENSE_FILE_BSD3CLAUSE=	${FILESDIR}/app/LICENSE

ONLY_FOR_ARCHS=	amd64
BUILD_DEPENDS=	dart=3.13.5:lang/dart \
		flutter-engine=0.1.0:x11-toolkits/flutter-engine
RUN_DEPENDS=	flutter-engine=0.1.0:x11-toolkits/flutter-engine \
		pkexec:sysutils/polkit

USES=		compiler:c++20-lang gnome pkgconfig python:build tar:xz
USE_GNOME=	gtk30

DART_CMD?=	${LOCALBASE}/bin/dart
ENGINE_PREFIX?=	${LOCALBASE}
_PUB_PACKAGES=	appkit_ui_element_colors-1.0.1 \
		characters-1.4.1 \
		collection-1.19.1 \
		cupertino_icons-1.0.8 \
		equatable-2.1.0 \
		gradient_borders-1.0.4 \
		macos_ui-2.2.2 \
		macos_window_utils-1.9.1 \
		material_color_utilities-0.13.0 \
		meta-1.18.3 \
		plugin_platform_interface-2.1.8 \
		vector_math-2.4.0
.for package in ${_PUB_PACKAGES}
DISTFILES+=	${package}.tar.gz:pub
.endfor

post-extract:
	${MKDIR} ${WRKDIR}/pub-cache/hosted-hashes/pub.dev
.for package in ${_PUB_PACKAGES}
	${MKDIR} ${WRKDIR}/pub-cache/hosted/pub.dev/${package}
	${TAR} -xf ${DISTDIR}/${DIST_SUBDIR}/${package}.tar.gz -C ${WRKDIR}/pub-cache/hosted/pub.dev/${package}
	${SHA256} -q ${DISTDIR}/${DIST_SUBDIR}/${package}.tar.gz > ${WRKDIR}/pub-cache/hosted-hashes/pub.dev/${package}.sha256
.endfor

do-build:
	${SETENV} PUB_CACHE=${WRKDIR}/pub-cache ${PYTHON_CMD} ${FILESDIR}/app/build.py \
		--flutter ${WRKSRC} --dart ${DART_CMD} --engine-prefix ${ENGINE_PREFIX} \
		--prefix ${PREFIX} --fonts ${DISTDIR}/${DIST_SUBDIR}/fonts.zip --output ${WRKDIR}/runtime

do-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/libexec/5bsd-imager/lib ${STAGEDIR}${PREFIX}/bin
	${INSTALL_PROGRAM} ${WRKDIR}/runtime/5bsd-imager ${STAGEDIR}${PREFIX}/libexec/5bsd-imager/
	${INSTALL_LIB} ${WRKDIR}/runtime/lib/libapp.so ${STAGEDIR}${PREFIX}/libexec/5bsd-imager/lib/
	(cd ${WRKDIR}/runtime && ${COPYTREE_SHARE} data ${STAGEDIR}${PREFIX}/libexec/5bsd-imager/)
	${INSTALL_PROGRAM} ${WRKDIR}/runtime/5bsd-imager-helper ${STAGEDIR}${PREFIX}/libexec/
	${INSTALL_SCRIPT} ${WRKDIR}/runtime/5bsd-imager-launch ${STAGEDIR}${PREFIX}/bin/5bsd-imager
	${MKDIR} ${STAGEDIR}${PREFIX}/share/polkit-1/actions ${STAGEDIR}${PREFIX}/share/applications \
		${STAGEDIR}${PREFIX}/share/icons/hicolor/scalable/apps
	${INSTALL_DATA} ${WRKDIR}/runtime/org.fivebsd.Imager.policy ${STAGEDIR}${PREFIX}/share/polkit-1/actions/
	${INSTALL_DATA} ${FILESDIR}/org.fivebsd.Imager.desktop ${STAGEDIR}${PREFIX}/share/applications/
	${INSTALL_DATA} ${FILESDIR}/org.fivebsd.Imager.svg ${STAGEDIR}${PREFIX}/share/icons/hicolor/scalable/apps/

do-test:
	${PYTHON_CMD} ${FILESDIR}/app/tests/run.py --work ${WRKDIR}/tests
	${DART_CMD} ${FILESDIR}/app/tests/writer_test.dart

.include <bsd.port.mk>
