#!/usr/bin/env bash

project_name="${1:-example}"
pypkg_name="${project_name//-/_}"
author="Dan Davis"
email="dan@dandavis.dev"
license="${HOME}/Documents/GPLv3"


read -r -d '' RUN_DOT_SH << EOM
#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

VENVPATH="./venv"

venv() {
    if [[ -d "\${VENVPATH}/bin" ]]; then
        echo "source \${VENVPATH}/bin/activate"
    else
        echo "source \${VENVPATH}/Scripts/activate"
    fi
}

make_venv() {
    python -m venv "\${VENVPATH}"
}

reset_venv() {
    rm -rf "\${VENVPATH}"
    make_venv
}

wrapped_python() {
    if [[ -d "\${VENVPATH}/bin" ]]; then
        "\${VENVPATH}"/bin/python "\$@"
    else
        "\${VENVPATH}"/Scripts/python "\$@"
    fi
}

wrapped_pip() {
    wrapped_python -m pip "\$@"
}

python_deps() {
    wrapped_pip install --upgrade pip setuptools wheel

    local pip_extras="\${1:-}"
    if [[ -z "\${pip_extras}" ]]; then
        wrapped_pip install -e .
    else
        wrapped_pip install -e ".[\${pip_extras}]"
    fi
}

install() {
    if [[ -d "\${VENVPATH}" ]]; then
        python_deps "\$@"
    else
        make_venv && python_deps "\$@"
    fi
}

build() {
    python -m build
}

publish() {
    lint && tests && clean && build
    python -m twine upload dist/*
}

clean() {
    rm -rf dist/
    rm -rf .eggs/
    rm -rf build/
    find . -name '*.pyc' -exec rm -f {} +
    find . -name '*.pyo' -exec rm -f {} +
    find . -name '*~' -exec rm -f {} +
    find . -name '__pycache__' -exec rm -fr {} +
    find . -name '.mypy_cache' -exec rm -fr {} +
    find . -name '.pytest_cache' -exec rm -fr {} +
    find . -name '*.egg-info' -exec rm -fr {} +
}

lint() {
    clean
    wrapped_python -m flake8 src/ &&
    wrapped_python -m mypy src/
}

tests() {
    wrapped_python -m pytest -rA tests/
}

default() {
    wrapped_python -i -c 'import ${pypkg_name}'
}

TIMEFORMAT="Task completed in %3lR"
time "\${@:-default}"
EOM

read -r -d '' PYPROJECT_DOT_TOML << EOM
[build-system]
requires = [
    "setuptools>=61.0.0",
    "wheel"
]
build-backend = "setuptools.build_meta"

[project]
name = "${project_name}"
version = "0.1.0"
description = ""
readme = "README.md"
authors = [{name = "${author}", email = "${email}"}]
license = { text = "GPL-3.0-or-later" }
classifiers = [
    "Programming Language :: Python :: 3",
    "License :: OSI Approved :: GNU General Public License v3 or later (GPLv3+)",
]
keywords = []
dependencies = []
requires-python = ">=3.10"

[project.optional-dependencies]
dev = [
    "black",
    "flake8",
    "flake8-isort",
    "flake8-docstrings",
    "mypy",
    "pytest",
]
doc = [
    "pdoc"
]

[project.urls]
Homepage = "https://github.com/danofsteel32/${project_name}"

# [project.scripts]
# ${project_name} = "${project_name}.cli:run"

[tool.isort]
line_length = 88
multi_line_output = 3
include_trailing_comma = true
force_grid_wrap = 0
use_parentheses = true

[tool.mypy]
exclude = ["venv/"]
ignore_missing_imports = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
disallow_untyped_defs = true

[[tool.mypy.overrides]]
module = "tests/*"
disallow_untyped_defs = false
EOM

read -r -d '' DOT_FLAKE8 << EOM
[flake8]
ignore = E203,W503
max-line-length = 88
docstring-convention=google
exclude =
    .git,
    __pycache__,
    build,
    dist
per-file-ignores =
    __init__.py: F401,D104
    tests/*: D103,D104
EOM

mkdir "${project_name}"

echo "$RUN_DOT_SH" > "${project_name}/run.sh"
chmod +x "${project_name}/run.sh"
echo "# ${project_name}" > "${project_name}/README.md"
echo "$PYPROJECT_DOT_TOML" > "${project_name}/pyproject.toml"
echo "$DOT_FLAKE8" > "${project_name}/.flake8"
cp "$license" "${project_name}/COPYING"

echo -e "graft src\ninclude COPYING" > "${project_name}/MANIFEST.in"

src_dir="${project_name}/src/${pypkg_name}"
mkdir -p "${src_dir}"
echo '__version__ = "0.1.0"' > "${src_dir}/__init__.py"

tests_dir="${project_name}/tests"
mkdir -p "${tests_dir}"
touch "${tests_dir}/__init__.py"
touch "${tests_dir}/conftest.py"
