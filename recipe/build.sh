# #!/usr/bin/env bash
# set -ex

# # Add compilation flags for disabling float16
# export CFLAGS="${CFLAGS} -D__NO_FLOAT16"
# export CPPFLAGS="${CPPFLAGS} -D__NO_FLOAT16"

# # Change into the HPB module directory
# cd "${SRC_DIR}/prody/proteins/hpbmodule"

# # Verify Fortran compiler is set
# if [ -z "${FC}" ]; then
#   echo "Fortran compiler (\$FC) not set. Aborting."
#   exit 1
# fi

# # Compile the Fortran source
# "${FC}" -O3 -fPIC -c reg_tet.f

# # Gather Python include & library paths
# PYTHON_INCLUDE="$(${PYTHON} -c 'from distutils.sysconfig import get_python_inc; print(get_python_inc())')"
# PYTHON_LIBDIR="$(${PYTHON} -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')"
# PYTHON_LIB="$(${PYTHON} -c 'import sysconfig; print(sysconfig.get_config_var("LDLIBRARY"))')"
# PYTHON_LIB_NAME="$(basename "${PYTHON_LIB}" | sed -E 's/^lib(.*)\.(so|dylib|a)$/\1/')"

# # Compile the C++ wrapper using the conda-provided compiler
# "${CXX}" -O3 -g -fPIC -c hpbmodule.cpp -o hpbmodule.o -I"${PYTHON_INCLUDE}"

# # Ensure linker can find libraries
# export LIBRARY_PATH="${PREFIX}/lib:${PYTHON_LIBDIR}:${LIBRARY_PATH}"

# # Link into a shared library (.so/.dylib)
# if [[ "$(uname)" == "Darwin" ]]; then
#   "${CXX}" -dynamiclib -o hpb.so hpbmodule.o reg_tet.o \
#     -L"${PYTHON_LIBDIR}" -l"${PYTHON_LIB_NAME}" -lgfortran -undefined dynamic_lookup
# else
#   "${CXX}" -shared -Wl,-soname,hpb.so -o hpb.so hpbmodule.o reg_tet.o \
#     -L"${PYTHON_LIBDIR}" -l"${PYTHON_LIB_NAME}" -lgfortran
# fi

# # Move the shared library back into the package directory
# mv hpb.so ../

# # Return to the source root and install the package via pip
# cd "${SRC_DIR}"
# "${PYTHON}" -m pip install . --no-deps --no-build-isolation -vv
#!/usr/bin/env bash
set -ex

# Let conda-build provide CC/CXX/FC (don’t override them)
echo "CC=$CC"
echo "CXX=$CXX"
echo "FC=$FC"
command -v "$CC" || true
command -v "$CXX" || true
command -v "$FC"  || true

# macOS SDK flags (safe to add; no-ops elsewhere)
if [[ "$(uname)" == "Darwin" ]]; then
  export CFLAGS="${CFLAGS} -isysroot ${CONDA_BUILD_SYSROOT} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -D__NO_FLOAT16"
  export CXXFLAGS="${CXXFLAGS} -isysroot ${CONDA_BUILD_SYSROOT} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -D__NO_FLOAT16"
  export FFLAGS="${FFLAGS} -isysroot ${CONDA_BUILD_SYSROOT} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
else
  export CFLAGS="${CFLAGS} -D__NO_FLOAT16"
  export CXXFLAGS="${CXXFLAGS} -D__NO_FLOAT16"
fi

cd "${SRC_DIR}/prody/proteins/hpbmodule"

# If we are cross-compiling to mac arm64 on an Intel runner, optionally skip Fortran
SKIP_FORTRAN=0
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" && "${HOST:-}" == arm64-apple-darwin* ]]; then
  # comment this out if you want to *try* the Fortran build first
  SKIP_FORTRAN=1
fi

if [[ "$SKIP_FORTRAN" -eq 0 ]]; then
  # Compile Fortran + C++ wrapper
  "$FC"  -O3 -fPIC -c reg_tet.f
  PY_INCLUDE="$(${PYTHON} - <<'PY'
import sysconfig; print(sysconfig.get_paths()["include"])
PY
)"
  "$CXX" -O3 -g -fPIC -I"${PY_INCLUDE}" -c hpbmodule.cpp -o hpbmodule.o

  if [[ "$(uname)" == "Darwin" ]]; then
    "$CXX" -dynamiclib -o hpb.so hpbmodule.o reg_tet.o \
      -Wl,-headerpad_max_install_names -Wl,-dead_strip_dylibs \
      -lgfortran -undefined dynamic_lookup
  else
    "$CXX" -shared -Wl,-soname,hpb.so -o hpb.so hpbmodule.o reg_tet.o -lgfortran
  fi

  mv hpb.so ../
else
  echo "Skipping Fortran (cross macOS arm64 on Intel)."
fi

cd "${SRC_DIR}"
"${PYTHON}" -m pip install . --no-deps --no-build-isolation -vv
