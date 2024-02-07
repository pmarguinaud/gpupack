
PREFIX=""
case $(hostname) in
	*belenos*)
		PREFIX="/opt/softs"
		;;
	*taranis*)
		PREFIX="/opt/softs"
		;;
	*bullx*)
		PREFIX="/ec/res4/hpcperm/sor/install"
		;;
	*)
		echo "Unknown host"
		exit 1
		;;
esac

NVHPC_PREFIX="$PREFIX/nvidia/hpc_sdk/Linux_x86_64/23.5"
CUDA_PREFIX="cuda/12.1"
NVHPC_CUDA_HOME="$NVHPC_PREFIX/$CUDA_PREFIX"

echo "export NVHPC_CUDA_HOME=$NVHPC_CUDA_HOME"
