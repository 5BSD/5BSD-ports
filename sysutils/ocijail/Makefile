PORTNAME=	ocijail
DISTVERSIONPREFIX=	v
DISTVERSION=	0.6.1
PORTREVISION=	1
CATEGORIES=	sysutils
MASTER_SITES=	https://github.com/5BSD/5BSD-ports/releases/download/ocijail-0.6.1-bzlmod-20261031/:bzlmod
DISTFILES=	${PORTNAME}-${DISTVERSION}-bzlmod-cache-20261031.tar.gz:bzlmod

MAINTAINER=	dfr@FreeBSD.org
COMMENT=	Experimental, proof-of-concept OCI-compatible runtime for jails
WWW=		https://github.com/dfr/ocijail

LICENSE=	BSD2CLAUSE
LICENSE_FILE=	${WRKSRC}/LICENSE

BUILD_DEPENDS=	bazel:devel/bazel9

USES=		java:build
JAVA_VERSION=	21
USE_GITHUB=	yes
GH_ACCOUNT=	dfr

PLIST_FILES=	bin/ocijail

# Bazel 9 removed WORKSPACE; files/patch-* add a MODULE.bazel (Bzlmod).
# Module resolution is offline: files/MODULE.bazel.lock pins the Bazel
# Central Registry files (it is the lockfile of /usr/src tools/build/bazel,
# rules_cc 0.2.17 / platforms 1.0.0, Bazel 9.3.1) and the bzlmod-cache
# distfile is a Bazel repository cache holding exactly those registry files
# and the module archives the build fetches.  CLI11 and nlohmann_json come
# from the distfiles/ directory of the ocijail source (.bazelrc --distdir).
BAZEL_OPTS=	--batch --output_user_root=${WRKDIR}/bazel_out
BAZEL_BUILD_OPTS=	-c opt --jobs=${MAKE_JOBS_NUMBER} \
		--repository_cache=${WRKDIR}/bazel-cache \
		--repository_disable_download --lockfile_mode=error

post-patch:
	${INSTALL_DATA} ${FILESDIR}/MODULE.bazel.lock ${WRKSRC}/MODULE.bazel.lock
	${CHMOD} 755 ${WRKSRC}/tools/install.sh

do-build:
	cd ${WRKSRC} && ${SETENVI} ${WRK_ENV} JAVA_HOME=${JAVA_HOME} \
		bazel ${BAZEL_OPTS} build ${BAZEL_BUILD_OPTS} //ocijail:ocijail

do-install:
	${INSTALL_PROGRAM} ${WRKSRC}/bazel-bin/ocijail/ocijail ${STAGEDIR}${PREFIX}/bin

.include <bsd.port.mk>
