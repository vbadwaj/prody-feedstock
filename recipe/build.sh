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
#!/usr/bin/env bash
set -Eeuo pipefail
set -x

echo "BUILD=${BUILD:-?}  HOST=${HOST:-?}"
echo "BUILD_PREFIX=${BUILD_PREFIX:-?}"
echo "PREFIX=${PREFIX:-?}"
echo "target_platform=${target_platform:-?}  build_platform=${build_platform:-?}"
echo "CC=$CC"
echo "CXX=$CXX"
echo "FC(initial)=${FC:-<unset>}"

if [[ -n "${BUILD_PREFIX:-}" && -n "${HOST:-}" && -x "${BUILD_PREFIX}/bin/${HOST}-gfortran" ]]; then
  export FC="${BUILD_PREFIX}/bin/${HOST}-gfortran"
fi

echo "FC(using)=$FC"
command -v "$FC"
"$FC" --version || true
file "$(command -v "$FC")" || true

export CFLAGS="${CFLAGS:-} -D__NO_FLOAT16"
export CPPFLAGS="${CPPFLAGS:-} -D__NO_FLOAT16"
export CXXFLAGS="${CXXFLAGS:-} -D__NO_FLOAT16"

pushd "${SRC_DIR}/prody/proteins/hpbmodule"

"$FC" -O3 -fPIC -c reg_tet.f

PY_INC="$("$PYTHON" - <<'PY'
import sysconfig
print(sysconfig.get_paths()["include"])
PY
)"

"$CXX" -O3 -g -fPIC -I"$PY_INC" -c hpbmodule.cpp -o hpbmodule.o

if [[ "$(uname)" == "Darwin" ]]; then
  "$CXX" -dynamiclib -o hpb.so hpbmodule.o reg_tet.o \
        ${LDFLAGS:-} \
        -lgfortran \
        -Wl,-rpath,"${PREFIX}/lib" \
        -undefined dynamic_lookup
  (command -v otool >/dev/null && otool -L hpb.so) || true
else
  "$CXX" -shared -o hpb.so hpbmodule.o reg_tet.o \
        ${LDFLAGS:-} \
        -lgfortran \
        -Wl,-rpath,"${PREFIX}/lib"
  (command -v readelf >/dev/null && readelf -d hpb.so | grep RPATH || true)
fi

mv -v hpb.so ../
popd

pushd "${SRC_DIR}"
"$PYTHON" -m pip install . --no-deps --no-build-isolation -vv
popd
