#!/bin/bash
set -eu

if [ ! -e config.sh ]; then
    echo "first configure your build:"
    echo "cp config.sh.template config.sh"
    echo "edit config.sh"
    exit -1
fi

source config.sh

CUR=`pwd`

function remote {
    if $HTTPS; then
        echo "https://github.com/$1"
    else
        echo "git@github.com:$1"
    fi
}

# fetch sources
if [ "$FETCH_LLVM" = true ] ; then
    wget http://llvm.org/releases/3.8.0/clang+llvm-3.8.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz
    tar -xvf clang+llvm-3.8.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz
    rm clang+llvm-3.8.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz
    mv clang+llvm-3.8.0-x86_64-linux-gnu-ubuntu-14.04/ llvm_install/
    
    find /home/travis/work/anydsl/llvm_install/share/llvm/cmake/ -type f -exec sed -i 's#/home/development/llvm/3.8.0/final/Phase3/Release/llvmCore-3.8.0-final.install/#/home/travis/work/anydsl/llvm_install/#g' {} \;
else
    mkdir -p llvm_build/
    
    if [ ! -e  "${CUR}/llvm" ]; then
        wget http://llvm.org/releases/3.4.2/llvm-3.4.2.src.tar.gz
        tar xf llvm-3.4.2.src.tar.gz
        rm llvm-3.4.2.src.tar.gz
        mv llvm-3.4.2.src llvm
        cd llvm/tools
        wget http://llvm.org/releases/3.4.2/cfe-3.4.2.src.tar.gz
        tar xf cfe-3.4.2.src.tar.gz
        rm cfe-3.4.2.src.tar.gz
        mv cfe-3.4.2.src clang
    fi
    
    # build llvm
    cd llvm_build
    cmake ../llvm -DLLVM_REQUIRES_RTTI:BOOL=true -DCMAKE_BUILD_TYPE:STRING=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX:PATH="${CUR}/llvm_install"
    make install -j${THREADS}
fi

cd "${CUR}"

if [ ! -e "${CUR}/half" ]; then
    svn checkout svn://svn.code.sf.net/p/half/code/trunk half
fi
if [ ! -e "${CUR}/thorin" ]; then
    git clone `remote AnyDSL/thorin.git` -b ${BRANCH}
fi
if [ ! -e "${CUR}/impala" ]; then
    git clone `remote AnyDSL/impala.git` -b ${BRANCH}
fi
if [ ! -e "${CUR}/libwfv" ]; then
    git clone `remote simoll/libwfv.git`
fi
if [ ! -e "${CUR}/stincilla" ]; then
    git clone --recursive `remote AnyDSL/stincilla.git`
fi

# create build/install dirs
mkdir -p thorin/build/
mkdir -p impala/build/
mkdir -p libwfv/build/
mkdir -p stincilla/build/

# build libwfv
if [ "$FETCH_LLVM" = false ] ; then
    cd "${CUR}/libwfv/build"
    cmake .. -DCMAKE_BUILD_TYPE:STRING=${BUILD_TYPE} -DLLVM_DIR:PATH="${CUR}/llvm_install/share/llvm/cmake"
    make -j${THREADS}
fi

COMMON_CMAKE_VARS=-DCMAKE_BUILD_TYPE:STRING=${BUILD_TYPE}\ -DHalf_DIR:PATH="${CUR}/half/include"\ -DLLVM_DIR:PATH="${CUR}/llvm_install/share/llvm/cmake"\ -DWFV2_DIR:PATH="${CUR}/libwfv"
# build thorin
cd "${CUR}/thorin/build"
cmake .. ${COMMON_CMAKE_VARS}
make -j${THREADS}

# build impala
cd "${CUR}/impala/build"
cmake .. ${COMMON_CMAKE_VARS} -DTHORIN_DIR:PATH="${CUR}/thorin"
make -j${THREADS}

cd "${CUR}"

# source this file to put clang and impala in your path
cat > "project.sh" <<_EOF_
export PATH="${CUR}/llvm_install/bin:${CUR}/impala/build/bin:\$PATH"
_EOF_

source project.sh

# configure stincilla but don't build yet
cd "${CUR}/stincilla/build"
cmake .. -DCMAKE_BUILD_TYPE:STRING=${BUILD_TYPE} -DLLVM_DIR:PATH="${CUR}/llvm_install/share/llvm/cmake" -DTHORIN_DIR:PATH="${CUR}/thorin" -DBACKEND:STRING="cpu"
#make -j${THREADS}

# symlink git hooks
#ln -s "${CUR}/scripts/pre-push-impala.hook" "${CUR}/impala/.git/hooks/pre-push"
#ln -s "${CUR}/scripts/pre-push-thorin.hook" "${CUR}/thorin/.git/hooks/pre-push"

echo
echo "Use the following command in order to have 'impala' and 'clang' in your path:"
echo "source project.sh"
echo "This has already been done for this shell session"
echo "WARNING: Note that this will override any system installation of llvm/clang in your current shell session."
