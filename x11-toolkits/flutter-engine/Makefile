PORTNAME=	flutter-engine
DISTVERSION=	0.1.0
_DART_VERSION=	3.13.5
CATEGORIES=	x11-toolkits
MASTER_SITES=	https://github.com/5BSD/5BSD-ports/releases/download/toolkit-20261004/
DISTNAME=	5bsd-flutter-eb529d2bebb5
DISTFILES=	${DISTNAME}${EXTRACT_SUFX} \
		dart-bootstrap-${_DART_VERSION}-5bsd-amd64${EXTRACT_SUFX}
DIST_SUBDIR=	5bsd-toolkit
USE_GITHUB=	nodefault
GH_TUPLE=	flutter:devtools:12d595649f189f1896722623f72599077f476848:devtools

MAINTAINER=	kory@5bsd.org
COMMENT=	Native 5BSD Flutter GTK rendering engine
WWW=		https://flutter.dev/

LICENSE=	BSD3CLAUSE
LICENSE_FILE=	${WRKSRC}/LICENSE

ONLY_FOR_ARCHS=	amd64
ONLY_FOR_ARCHS_REASON=	native bootstrap SDK is currently validated on amd64

BUILD_DEPENDS=	gn:devel/gn \
		${LOCALBASE}/libdata/pkgconfig/gtk+-3.0.pc:x11-toolkits/gtk30 \
		${LOCALBASE}/libdata/pkgconfig/fontconfig.pc:x11-fonts/fontconfig

USES=		compiler:c++20-lang gnome ninja:build pkgconfig python:build tar:xz

USE_LDCONFIG=	yes
USE_GNOME=	atk cairo gdkpixbuf glib20 gtk30 pango
LIB_DEPENDS=	libepoxy.so:graphics/libepoxy \
		libfontconfig.so:x11-fonts/fontconfig
SUB_FILES=	flutter-engine.pc
SUB_LIST=	VERSION=${DISTVERSION}

CONFIGURE_ENV+=	PUB_CACHE=${WRKDIR}/pub-cache

_BOOTSTRAP=	${WRKDIR}/dart-bootstrap-${_DART_VERSION}-5bsd-amd64
_DART=		${WRKSRC}/engine/src/flutter/third_party/dart
_ENGINE_OUT=	${WRKSRC}/engine/src/out/host_release_ports
_SDK=		${_ENGINE_OUT}/dart-sdk

# All sources and the native stage-zero SDK are fetched and checksummed by
# ports. Configure/build never use gclient, CIPD, Git, or a Linux executable.
do-configure:
	${CP} ${FILESDIR}/dist-versions.json ${WRKSRC}/docs/5bsd/dist-versions.json
	cd ${WRKSRC} && ${PYTHON_CMD} tools/5bsd/prepare_checkout.py
	${MKDIR} ${_DART}/tools/sdks ${_DART}/third_party/devtools
	(cd ${WRKSRC_devtools}/packages/devtools_shared && ${COPYTREE_SHARE} . ${_DART}/third_party/devtools/devtools_shared)
	${LN} -sf ${_BOOTSTRAP} ${_DART}/tools/sdks/dart-sdk
	(cd ${_BOOTSTRAP}/bin/resources/devtools && ${COPYTREE_SHARE} . ${_DART}/third_party/devtools/web)
	cd ${WRKSRC} && ${SETENV} ${CONFIGURE_ENV} ${PYTHON_CMD} ${_DART}/tools/generate_package_config.py
	cd ${WRKSRC} && ${SETENV} ${CONFIGURE_ENV} ${PYTHON_CMD} engine/src/flutter/tools/gn \
		--runtime-mode=release --full-dart-sdk --no-prebuilt-dart-sdk \
		--no-build-embedder-examples --no-enable-unittests \
		--no-dart-version-git-info --target-dir=host_release_ports

do-build:
	${SETENV} ${MAKE_ENV} ${NINJA_CMD} -C ${_ENGINE_OUT} -j${MAKE_JOBS_NUMBER} \
		flutter/shell/platform/linux:flutter_linux_gtk \
		flutter/shell/platform/linux:publish_headers_linux \
		flutter/lib/snapshot:kernel_platform_files \
		gen_snapshot

post-build:
	${PYTHON_CMD} ${FILESDIR}/collect-notices.py ${WRKSRC} ${WRKDIR}/THIRD_PARTY_NOTICES

do-install:
	${INSTALL_LIB} ${_ENGINE_OUT}/libflutter_5bsd_gtk.so ${STAGEDIR}${PREFIX}/lib
	${MKDIR} ${STAGEDIR}${PREFIX}/include/flutter_linux \
		${STAGEDIR}${PREFIX}/libexec/flutter-engine ${STAGEDIR}${DATADIR}/flutter_patched_sdk
	(cd ${_ENGINE_OUT}/flutter_linux && ${COPYTREE_SHARE} . ${STAGEDIR}${PREFIX}/include/flutter_linux)
	${INSTALL_PROGRAM} ${_ENGINE_OUT}/gen_snapshot ${STAGEDIR}${PREFIX}/libexec/flutter-engine/gen_snapshot
	${INSTALL_DATA} ${_ENGINE_OUT}/flutter_patched_sdk/*.dill ${STAGEDIR}${DATADIR}/flutter_patched_sdk/
	${INSTALL_DATA} ${WRKSRC}/engine/src/flutter/third_party/icu/flutter_desktop/icudtl.dat ${STAGEDIR}${DATADIR}/icudtl.dat
	${INSTALL_DATA} ${WRKDIR}/THIRD_PARTY_NOTICES ${STAGEDIR}${DATADIR}/THIRD_PARTY_NOTICES
	${INSTALL_DATA} ${FILESDIR}/dist-versions.json ${STAGEDIR}${DATADIR}/versions.json
	${INSTALL_DATA} ${WRKDIR}/flutter-engine.pc ${STAGEDIR}${PREFIX}/libdata/pkgconfig/

.include <bsd.port.mk>
