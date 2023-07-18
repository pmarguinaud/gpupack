sbatch --mem=247000 --ntasks-per-node 256  -N1     -p par mpitest.sh 
sbatch --mem=247000 --ntasks-per-node 256  -N1 -G4 -p gpu mpitest.sh 
