PORTNAME=	dart
DISTVERSION=	3.13.5
CATEGORIES=	lang
MASTER_SITES=	https://github.com/5BSD/5BSD-ports/releases/download/toolkit-20261004/
DISTNAME=	5bsd-flutter-eb529d2bebb5
DISTFILES=	${DISTNAME}${EXTRACT_SUFX} \
		dart-bootstrap-${DISTVERSION}-5bsd-amd64${EXTRACT_SUFX}
DIST_SUBDIR=	5bsd-toolkit
USE_GITHUB=	nodefault
GH_TUPLE=	flutter:devtools:12d595649f189f1896722623f72599077f476848:devtools

MAINTAINER=	kory@5bsd.org
COMMENT=	Native 5BSD Dart language SDK
WWW=		https://dart.dev/

LICENSE=	BSD3CLAUSE
LICENSE_FILE=	${WRKSRC}/engine/src/flutter/third_party/dart/LICENSE

ONLY_FOR_ARCHS=	amd64
ONLY_FOR_ARCHS_REASON=	native bootstrap SDK is currently validated on amd64

BUILD_DEPENDS=	gn:devel/gn \
		${LOCALBASE}/libdata/pkgconfig/gtk+-3.0.pc:x11-toolkits/gtk30 \
		${LOCALBASE}/libdata/pkgconfig/fontconfig.pc:x11-fonts/fontconfig

USES=		compiler:c++20-lang ninja:build pkgconfig python:build tar:xz

CONFIGURE_ENV+=	PUB_CACHE=${WRKDIR}/pub-cache

_BOOTSTRAP=	${WRKDIR}/dart-bootstrap-${DISTVERSION}-5bsd-amd64
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
		flutter/third_party/dart/sdk:create_most_sdk

do-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/lib/dart
	${CP} -R ${_SDK}/. ${STAGEDIR}${PREFIX}/lib/dart/
.for binary in dart dartvm dartaotruntime
	${INSTALL_PROGRAM} ${_SDK}/bin/${binary} ${STAGEDIR}${PREFIX}/lib/dart/bin/${binary}
	${LN} -s ../lib/dart/bin/${binary} ${STAGEDIR}${PREFIX}/bin/${binary}
.endfor
	${INSTALL_PROGRAM} ${_SDK}/bin/utils/gen_snapshot ${STAGEDIR}${PREFIX}/lib/dart/bin/utils/gen_snapshot
	${FIND} ${STAGEDIR}${PREFIX}/lib/dart/bin/snapshots -name '*_aot.dart.snapshot' -exec ${STRIP_CMD} {} +

do-test:
	${_SDK}/bin/dart --version
	${_SDK}/bin/dart ${FILESDIR}/smoke.dart
	${_SDK}/bin/dart compile exe ${FILESDIR}/smoke.dart -o ${WRKDIR}/dart-smoke
	${WRKDIR}/dart-smoke

.include <bsd.port.mk>
