PORTNAME=	mojo
DISTVERSION=	1.2.0.d2026100805
CATEGORIES=	lang
DIST_SUBDIR=	${PORTNAME}/${DISTVERSION}

MAINTAINER=	kory@5bsd.org
COMMENT=	Native Mojo compiler and language tools for 5BSD
WWW=		https://github.com/modular/modular

LICENSE=	Apache-2.0-with-LLVM-exception MIT PSFL
LICENSE_COMB=	multi
LICENSE_NAME_Apache-2.0-with-LLVM-exception=	Apache License 2.0 with LLVM exceptions
LICENSE_FILE_Apache-2.0-with-LLVM-exception=	${WRKSRC}/LICENSE
LICENSE_PERMS_Apache-2.0-with-LLVM-exception=	dist-mirror dist-sell pkg-mirror pkg-sell auto-accept
LICENSE_FILE_MIT=	${WRKSRC}/Mojo/tools/mblack/LICENSE
LICENSE_FILE_PSFL=	${WRKSRC}/Mojo/tools/mblack/src/mblib2to3/LICENSE

ONLY_FOR_ARCHS=	amd64
ONLY_FOR_ARCHS_REASON=	only native amd64 FreeBSD 16 has been qualified

BUILD_DEPENDS=	bazel9>=9.2.0:devel/bazel9 \
		chrpath:devel/chrpath
LIB_DEPENDS=	libcurl.so:ftp/curl
RUN_DEPENDS=	${PYTHON_PKGNAMEPREFIX}click>=8.0:devel/py-click@${PY_FLAVOR} \
		${PYTHON_PKGNAMEPREFIX}mypy_extensions>=1.0:devel/py-mypy_extensions@${PY_FLAVOR} \
		${PYTHON_PKGNAMEPREFIX}pathspec>=0.9:devel/py-pathspec@${PY_FLAVOR} \
		${PYTHON_PKGNAMEPREFIX}platformdirs>=2:devel/py-platformdirs@${PY_FLAVOR} \
		${PYTHON_PKGNAMEPREFIX}tomli>=1.1:textproc/py-tomli@${PY_FLAVOR}
TEST_DEPENDS=	bash:shells/bash \
		${PYTHON_PKGNAMEPREFIX}pytest>=8.2:devel/py-pytest@${PY_FLAVOR} \
		${PYTHON_PKGNAMEPREFIX}numpy>0:math/py-numpy@${PY_FLAVOR}

USES=		compiler:c++20-lang python:3.12
USE_GITHUB=	yes
GH_ACCOUNT=	modular
GH_PROJECT=	modular
GH_TAGNAME=	babedf564bd7e128bd161453f341f6b4b61aa3ca
EXTRACT_ONLY=	${DISTFILE_DEFAULT}
PATCH_STRIP=	-p1

# Every Bazel registry file, overlay and source archive is a distfile.
# Fetching happens in do-fetch; repository downloads are disabled for build.
.include "Makefile.inputs"
.include "Makefile.tests"

BAZEL?=		${LOCALBASE}/bin/bazel
CHRPATH?=	${LOCALBASE}/bin/chrpath
BAZEL_STARTUP_ARGS?=	--batch --ignore_all_rc_files \
		--output_user_root=${WRKDIR}/bazel-user \
		--output_base=${WRKDIR}/bazel-output \
		--host_jvm_args=-Xmx8g
BAZEL_ARGS=	--//:use_prebuilt_mojo_toolchain=false \
		--//:mojo_version_label=.dev2026100805 \
		--//:modular_version_sha=${GH_TAGNAME} \
		--jobs=${MAKE_JOBS_NUMBER} --compilation_mode=opt \
		--cxxopt=-std=c++20 --host_cxxopt=-std=c++20 \
		--dynamic_mode=off --features=-supports_dynamic_linker \
		--repo_env=CC=${CC} --repo_env=CXX=${CXX} \
		--repo_env=MOJO_PYTHON=${PYTHON_CMD} \
		--repo_env=BAZEL_HTTP_RULES_URLS_AS_DEFAULT_CANONICAL_ID=0 \
		--repository_cache=${WRKDIR}/bazel-cache \
		--repository_disable_download --lockfile_mode=error \
		--spawn_strategy=standalone --test_strategy=standalone \
		--host_platform=@platforms//host --platforms=@platforms//host \
		--extra_toolchains=@freebsd_python_toolchains//:all \
		--@llvm-project//third-party:llvm_enable_lzma=false \
		--color=no --curses=no

SUB_FILES=	mojo mojo-lsp-server mblack
SUB_LIST=	PYTHON_CMD=${PYTHON_CMD}

OPTIONS_DEFINE=	DOCS EXAMPLES
PORTDOCS=	README.md
PORTEXAMPLES=	operators process python-interop

.include <bsd.port.pre.mk>

.if ${OPSYS} != FreeBSD || ${OSVERSION} < 1600000
IGNORE=	uses the FreeBSD 16 native ABI
.endif

do-fetch:
	@${SH} ${FILESDIR}/fetch-inputs.sh ${FILESDIR}/inputs.tsv ${DISTDIR}/${DIST_SUBDIR}

post-extract:
	@${SH} ${FILESDIR}/prepare-cache.sh ${FILESDIR}/inputs.tsv \
		${DISTDIR}/${DIST_SUBDIR} ${WRKDIR}/bazel-cache
	${CP} ${FILESDIR}/MODULE.bazel.lock ${WRKSRC}/MODULE.bazel.lock

post-patch:
	@${REINPLACE_CMD} -e 's|/usr/local/bin/python3.12|${PYTHON_CMD}|g' \
		${WRKSRC}/MODULE.bazel
	@${REINPLACE_CMD} -e 's|/usr/local/lib|${LOCALBASE}/lib|g' \
		${WRKSRC}/bazel/public-patches/curl-freebsd.patch

do-build:
	cd ${WRKSRC} && ${SETENV} ${MAKE_ENV} ${BAZEL} ${BAZEL_STARTUP_ARGS} build \
		${BAZEL_ARGS} //Mojo/tools/mojo:mojo //Mojo:CompilerRT //Mojo/stdlib/std:std \
		//Mojo/tools/mojo-lsp-server:mojo-lsp-server

do-test:
	cd ${WRKSRC} && ${SETENV} ${TEST_ENV} ${BAZEL} ${BAZEL_STARTUP_ARGS} test \
		${BAZEL_ARGS} --test_output=errors \
		--test_env=MODULAR_RUNNING_TESTS=true --test_env=KMP_AFFINITY=none \
		--test_env=MODULAR_TELEMETRY_ENABLED=0 \
		--test_env=MODULAR_CRASH_REPORTING_ENABLED=0 \
		'--per_file_copt=Support/unittests/(AssertStream|Buffer|Context)Test.cpp@-UNDEBUG' \
		--test_tag_filters=-gpu --build_tag_filters=-gpu -- \
		//Support/unittests:BaseTest //Support/unittests:HostTest \
		//Support/unittests:LogTest //Support/unittests:LogEdgeCasesTest \
		//Support/unittests:BinaryIDTest //Mojo/unittests:unittests \
		//Mojo/unittests:KGENDialectTest //Mojo/unittests/CompilerRT:GlobalsTest \
		//Mojo/test/mojo-parser:all //Mojo/test/kgen:all \
		//Mojo/test/mojo-tool:freebsd_cpu \
		//Mojo/test/mojo-integration:freebsd_cpu \
		//Mojo/test/mojo-integration:freebsd_cpu.validate_lit_features \
		//Mojo/test/mojo-integration:test_std_srcs \
		//Mojo/test/mojo-integration:test_std_srcs.validate_lit_features \
		//Mojo/test/compilation-server:compilation-server \
		//Mojo/test/mojo-integration/extern-c-abi:test \
		//Mojo/test/mojo-integration/extern-c-effect:test \
		//Mojo/stdlib/test/... //Mojo/examples/operators:operators_test \
		//Mojo/examples/life:test_gridv1 //Mojo/examples/life:test_gridv2 \
		//Mojo/examples/python-interop:hello_test \
		//Mojo/examples/python-interop:person_test \
		//Mojo/examples/process:process_example \
		${MOJO_EXTRA_TEST_TARGETS} \
		-//Mojo/stdlib/test/_plugin:test_gpu_target_plugin.mojo.test \
		-//Mojo/stdlib/test/builtin:test_device_passable.mojo.test \
		-//Mojo/stdlib/test/gpu:test_target_accelerator_detection.mojo.test
	${WRKSRC}/bazel-bin/Mojo/examples/process/process_example
	cd ${WRKSRC}/bazel-bin && ${SETENV} ${TEST_ENV} ${PYTHON_CMD} -m unittest \
		discover -v -s ${WRKSRC}/Support/test/configuration -p test_config_with_env.py
	${MAKE_CMD} test-formatter

# Run outside Bazel so source-filesystem discovery cases are exercised too.
test-formatter: test-depends
	cd ${WRKSRC}/Mojo/tools/mblack && ${SETENV} ${TEST_ENV} \
		PYTHONPATH=${WRKSRC}/Mojo/tools/mblack/src:${WRKSRC}/Mojo/tools/mblack \
		PYTHONDONTWRITEBYTECODE=1 PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 \
		${PYTHON_CMD} -m pytest tests -q -ra -o xfail_strict=true \
		-p no:cacheprovider --junitxml=${WRKDIR}/formatter-tests.xml

# Exercise upstream Python tests against the actual staged package.
test-python-package: stage test-depends
	${SETENV} ${TEST_ENV} ${PYTHON_CMD} ${FILESDIR}/test-python-package.py \
		--source ${WRKSRC} --prefix ${STAGEDIR}${PREFIX} \
		--output ${WRKDIR}/python-package-tests

do-install:
	@${MKDIR} ${STAGEDIR}${PREFIX}/libexec/mojo/bin \
		${STAGEDIR}${PREFIX}/libexec/mojo/lib/mojo \
		${STAGEDIR}${PYTHONPREFIX_SITELIBDIR}/mojo
	${INSTALL_PROGRAM} ${WRKSRC}/bazel-bin/Mojo/tools/mojo/mojo \
		${WRKSRC}/bazel-bin/Mojo/tools/mojo-lsp-server/mojo-lsp-server \
		${STAGEDIR}${PREFIX}/libexec/mojo/bin/
	${INSTALL_LIB} ${WRKSRC}/bazel-bin/Mojo/libKGENCompilerRTShared.so \
		${WRKSRC}/bazel-bin/Support/libMSupportGlobals.so \
		${WRKSRC}/bazel-bin/AsyncRT/libAsyncRTRuntimeGlobals.so \
		${STAGEDIR}${PREFIX}/libexec/mojo/lib/
	${CHMOD} u+w ${STAGEDIR}${PREFIX}/libexec/mojo/bin/*
	${CHRPATH} -r '$$ORIGIN/../lib:${LOCALBASE}/lib' ${STAGEDIR}${PREFIX}/libexec/mojo/bin/*
	${CHMOD} ${BINMODE} ${STAGEDIR}${PREFIX}/libexec/mojo/bin/*
	${CHRPATH} -r '$$ORIGIN' ${STAGEDIR}${PREFIX}/libexec/mojo/lib/libKGENCompilerRTShared.so \
		${STAGEDIR}${PREFIX}/libexec/mojo/lib/libAsyncRTRuntimeGlobals.so
	${INSTALL_DATA} ${WRKSRC}/bazel-bin/Mojo/stdlib/std/std.mojoc \
		${STAGEDIR}${PREFIX}/libexec/mojo/lib/mojo/
	${INSTALL_SCRIPT} ${WRKDIR}/mojo ${WRKDIR}/mojo-lsp-server ${STAGEDIR}${PREFIX}/bin/
	${INSTALL_DATA} ${WRKSRC}/Mojo/python/mojo/*.py ${STAGEDIR}${PYTHONPREFIX_SITELIBDIR}/mojo/
	${INSTALL_SCRIPT} ${WRKDIR}/mblack ${STAGEDIR}${PREFIX}/libexec/mojo/bin/
.for module in mblack mblib2to3 mblib2to3/pgen2
	@${MKDIR} ${STAGEDIR}${PREFIX}/libexec/mojo/lib/mblack/${module}
	${INSTALL_DATA} ${WRKSRC}/Mojo/tools/mblack/src/${module}/*.py \
		${STAGEDIR}${PREFIX}/libexec/mojo/lib/mblack/${module}/
.endfor
	${INSTALL_DATA} ${WRKSRC}/Mojo/tools/mblack/src/_mblack_version.py \
		${STAGEDIR}${PREFIX}/libexec/mojo/lib/mblack/
	${INSTALL_DATA} ${WRKSRC}/Mojo/tools/mblack/src/mblib2to3/*.txt \
		${STAGEDIR}${PREFIX}/libexec/mojo/lib/mblack/mblib2to3/

post-install-DOCS-on:
	@${MKDIR} ${STAGEDIR}${DOCSDIR}
	${INSTALL_DATA} ${WRKSRC}/Mojo/README.md ${STAGEDIR}${DOCSDIR}/

post-install-EXAMPLES-on:
.for example in operators process python-interop
	@${MKDIR} ${STAGEDIR}${EXAMPLESDIR}/${example}
.endfor
	${INSTALL_DATA} ${WRKSRC}/Mojo/examples/operators/*.mojo ${STAGEDIR}${EXAMPLESDIR}/operators/
	${INSTALL_DATA} ${WRKSRC}/Mojo/examples/process/process_example.mojo ${STAGEDIR}${EXAMPLESDIR}/process/
.for example in hello.py hello_mojo.mojo person.py person_module.mojo
	${INSTALL_DATA} ${WRKSRC}/Mojo/examples/python-interop/${example} ${STAGEDIR}${EXAMPLESDIR}/python-interop/
.endfor

.include <bsd.port.post.mk>
