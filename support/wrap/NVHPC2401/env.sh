#!/bin/bash
NVHPC_VERSION=24.1
CUDA_VERSION=12.3

PREFIX=""

case $(hostname) in
	*belenos*)
		PREFIX=/opt/softs
		;;
	*taranis*)
		PREFIX=/opt/softs
		;;
	*bullx*)
		PREFIX=/ec/res4/hpcperm/sor/install
		;;
	*)
		echo "Unknown host"
		exit 1
		;;
esac

NVHPC_PREFIX="$PREFIX/gcc/9.2.0/hpc_sdk/Linux_x86_64/$NVHPC_VERSION"
CUDA_PREFIX="cuda/$CUDA_VERSION"
NVHPC_CUDA_HOME="$NVHPC_PREFIX/$CUDA_PREFIX"

echo "export NVHPC_CUDA_HOME=$NVHPC_CUDA_HOME"
echo "export CPATH=$NVHPC_PREFIX/comm_libs/$CUDA_VERSION/hpcx/latest/ompi/include\${CPATH:+:\$CPATH}"
