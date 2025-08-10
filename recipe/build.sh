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

echo "Target Platform: ${target_platform}"
echo "Build Platform: ${build_platform}"

export CFLAGS="${CFLAGS} -D__NO_FLOAT16"
export CPPFLAGS="${CPPFLAGS} -D__NO_FLOAT16"
export CXXFLAGS="${CXXFLAGS} -D__NO_FLOAT16"

cd "${SRC_DIR}/prody/proteins/hpbmodule"

if [ -z "${FC}" ]; then
  echo "Fortran compiler (\$FC) not set. Aborting."
  exit 1
fi

"${FC}" -O3 -fPIC -c reg_tet.f

PYTHON_INCLUDE="$(${PYTHON} -c 'from distutils.sysconfig import get_python_inc; print(get_python_inc())')"
PYTHON_LIBDIR="$(${PYTHON} -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')"
PYTHON_LIB="$(${PYTHON} -c 'import sysconfig; print(sysconfig.get_config_var("LDLIBRARY"))')"
PYTHON_LIB_NAME="$(basename "${PYTHON_LIB}" | sed -E 's/^lib(.*)\.(so|dylib|a)$/\1/')"

"${CXX}" -O3 -g -fPIC -c hpbmodule.cpp -o hpbmodule.o -I"${PYTHON_INCLUDE}"

if [[ "${target_platform}" == "osx-arm64" ]]; then
  "${CXX}" -dynamiclib -o hpb.so hpbmodule.o reg_tet.o \
    -L"${PREFIX}/lib" \
    -L"${PYTHON_LIBDIR}" -l"${PYTHON_LIB_NAME}" \
    -lgfortran \
    -Wl,-rpath,"${PREFIX}/lib" \
    -Wl,-rpath,"${PYTHON_LIBDIR}" \
    -undefined dynamic_lookup
elif [[ "${target_platform}" == "osx-64" ]]; then
  "${CXX}" -dynamiclib -o hpb.so hpbmodule.o reg_tet.o \
    -L"${PREFIX}/lib" \
    -L"${PYTHON_LIBDIR}" -l"${PYTHON_LIB_NAME}" \
    -lgfortran \
    -Wl,-rpath,"${PREFIX}/lib" \
    -Wl,-rpath,"${PYTHON_LIBDIR}" \
    -undefined dynamic_lookup
else
  "${CXX}" -shared -Wl,-soname,hpb.so -o hpb.so hpbmodule.o reg_tet.o \
    -L"${PREFIX}/lib" \
    -L"${PYTHON_LIBDIR}" -l"${PYTHON_LIB_NAME}" \
    -lgfortran \
    -Wl,-rpath,"${PREFIX}/lib" \
    -Wl,-rpath,"${PYTHON_LIBDIR}"
fi

mv hpb.so ../

cd "${SRC_DIR}"
"${PYTHON}" -m pip install . --no-deps --no-build-isolation -vv
