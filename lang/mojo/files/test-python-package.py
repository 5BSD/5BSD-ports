"""Run upstream Python tests against a staged or unpacked native Mojo package."""

import argparse
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, required=True)
parser.add_argument("--prefix", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
source, prefix, output = (p.resolve() for p in (args.source, args.prefix, args.output))
output.mkdir(parents=True, exist_ok=True)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
sdk = prefix / "libexec/mojo"
python_package = prefix / f"lib/python{sys.version_info.major}.{sys.version_info.minor}/site-packages"
env = os.environ.copy()
env.update(
    PYTHONDONTWRITEBYTECODE="1", PYTEST_DISABLE_PLUGIN_AUTOLOAD="1",
    MODULAR_MOJO_MAX_PACKAGE_ROOT=str(sdk),
    MODULAR_MOJO_MAX_DRIVER_PATH=str(sdk / "bin/mojo"),
    MODULAR_MOJO_MAX_IMPORT_PATH=str(sdk / "lib/mojo"),
    MODULAR_MOJO_MAX_LINKER_DRIVER="/usr/bin/clang",
    MODULAR_TELEMETRY_ENABLED="0", MODULAR_CRASH_REPORTING_ENABLED="0",
    MOJO_PYTHON=sys.executable,
    PYTHONPATH=str(python_package) + os.pathsep + env.get("PYTHONPATH", ""),
)
results = {}


def pytest_run(name, work, files):
    # Match the upstream launcher: fixtures use Python.evaluate with __main__.sys.
    command = [sys.executable, "-c",
               "import sys, pytest; raise SystemExit(pytest.main(sys.argv[1:]))",
               "-q", "-o", "addopts=", "-p", "no:cacheprovider",
               "--confcutdir=" + str(work),
               "--junitxml=" + str(work / "tests.xml"), *map(str, files)]
    with (work / "tests.log").open("w") as log:
        run = subprocess.run(command, cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT)
    result = {"exit_code": run.returncode}
    if (work / "tests.xml").exists():
        suites = list(ET.parse(work / "tests.xml").getroot().iter("testsuite"))
        for field in ("tests", "failures", "errors", "skipped"):
            result[field] = sum(int(s.get(field, 0)) for s in suites)
    results[name] = result
    print(name, json.dumps(result), flush=True)


unit = output / "mojo-python"
shutil.copytree(source / "Mojo/python/test", unit, dirs_exist_ok=True)
pytest_run("mojo-python", unit, [unit / "test_importer.py", unit / "test_paths.py"])
for case in sorted((source / "Mojo/integration-test/python-extension-modules").iterdir()):
    if not case.is_dir():
        continue
    work = output / case.name
    shutil.copytree(case, work, dirs_exist_ok=True)
    if case.name in ("nested_relative_import", "readonly-cache"):
        modules = []
    elif case.name == "multi-module":
        modules = [("mojo_module_a", "mojo_module_a"), ("mojo_module_b", "mojo_module_b")]
    elif case.name == "so-mojo-test":
        modules = [("module1", "module2")]
    else:
        modules = [("mojo_module", "mojo_module")]
    built = True
    for library, module in modules:
        command = [str(prefix / "bin/mojo"), "build", str(work / (module + ".mojo")),
                   "--emit", "shared-lib", "-D", "ASSERT=all", "-I", str(work),
                   "-o", str(work / (library + ".so"))]
        with (work / (library + "-build.log")).open("w") as log:
            run = subprocess.run(command, cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT)
        if run.returncode:
            results[case.name] = {"build_exit_code": run.returncode}
            built = False
            break
    if built:
        pytest_run(case.name, work, [work / "test_module.py"])
    (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
sys.exit(any(result.get("exit_code", 1) for result in results.values()))
