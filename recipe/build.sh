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

# Cross-friendly compilers: use build-env wrappers that *run on the builder*
# (they emit target code for ${HOST}, e.g. arm64-apple-darwin20.0.0)
export CC="${BUILD_PREFIX}/bin/${HOST}-clang"
export CXX="${BUILD_PREFIX}/bin/${HOST}-clang++"
export FC="${BUILD_PREFIX}/bin/${HOST}-gfortran"

# Helpful log
echo "BUILD=${BUILD} HOST=${HOST}"
which ${CC} || true
which ${CXX} || true
which ${FC}  || true

# macOS sysroot + min version (needed for both native and cross)
if [[ "$(uname)" == "Darwin" ]]; then
  export CFLAGS="${CFLAGS} -isysroot ${CONDA_BUILD_SYSROOT} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -D__NO_FLOAT16"
  export CXXFLAGS="${CXXFLAGS} -isysroot ${CONDA_BUILD_SYSROOT} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -D__NO_FLOAT16"
  export FFLAGS="${FFLAGS} -isysroot ${CONDA_BUILD_SYSROOT} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
else
  export CFLAGS="${CFLAGS} -D__NO_FLOAT16"
  export CXXFLAGS="${CXXFLAGS} -D__NO_FLOAT16"
fi

# Build the HPB extension (Fortran + C++)
cd "${SRC_DIR}/prody/proteins/hpbmodule"

# Compile Fortran
${FC} -O3 -fPIC -c reg_tet.f

# Python headers (for the C++ wrapper)
PY_INCLUDE="$(${PYTHON} - <<'PY'
import sysconfig; print(sysconfig.get_paths()["include"])
PY
)"

# Compile C++ wrapper
${CXX} -O3 -g -fPIC -I"${PY_INCLUDE}" -c hpbmodule.cpp -o hpbmodule.o

# Link shared lib
if [[ "$(uname)" == "Darwin" ]]; then
  # Do NOT link libpython on mac; use undefined dynamic lookup
  ${CXX} -dynamiclib -o hpb.so hpbmodule.o reg_tet.o \
    -Wl,-headerpad_max_install_names \
    -Wl,-dead_strip_dylibs \
    -lgfortran -undefined dynamic_lookup
else
  ${CXX} -shared -Wl,-soname,hpb.so -o hpb.so hpbmodule.o reg_tet.o \
    -lgfortran
fi

mv hpb.so ../

# Install package
cd "${SRC_DIR}"
${PYTHON} -m pip install . --no-deps --no-build-isolation -vv
