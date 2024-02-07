#!/bin/bash
NVHPC_VERSION=23.11
CUDA_VERSION=12.3

PREFIX=""
GCC_PATH=""
GCC_LIBARAY_PATH=""

case $(hostname) in
	*belenos*)
		PREFIX="/opt/softs"
		GCC_PATH=/opt/softs/gcc/9.2.0/bin
		GCC_LIBARAY_PATH=/opt/softs/gcc/9.2.0/lib64
		;;
	*taranis*)
		PREFIX="/opt/softs"
		GCC_PATH=/opt/softs/gcc/9.2.0/bin
		GCC_LIBARAY_PATH=/opt/softs/gcc/9.2.0/lib64
		;;
	*bullx*)
		PREFIX="/ec/res4/hpcperm/sor/install"
		;;
	*)
		echo "Unknown host"
		exit 1
		;;
esac

NVHPC_PREFIX="$PREFIX/nvidia/hpc_sdk/Linux_x86_64/$NVHPC_VERSION"
CUDA_PREFIX="cuda/$CUDA_VERSION"
NVHPC_CUDA_HOME="$NVHPC_PREFIX/$CUDA_PREFIX"

echo "export NVHPC_CUDA_HOME=$NVHPC_CUDA_HOME"
echo "export CPATH=$NVHPC_PREFIX/comm_libs/$CUDA_VERSION/hpcx/latest/ompi/include:$CPATH"
if [ ! -z $GCC_PATH ]; then
	echo "export PATH=$GCC_PATH:\$PATH"
	echo "export LD_LIBRARY_PATH=$GCC_LIBARAY_PATH:\$LD_LIBRARY_PATH"
fi
