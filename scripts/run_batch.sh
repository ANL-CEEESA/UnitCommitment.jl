#!/bin/bash
#SBATCH --array=1-180
#SBATCH --time=02:00:00
#SBATCH --account=def-alodi
#SBATCH --mem-per-cpu=1G
#SBATCH --cpus-per-task=4
#SBATCH --mail-user=aleksandr.kazachkov@polymtl.ca
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL
#SBATCH --array=182
#SBATCH --time=00:00:30
#SBATCH --mem-per-cpu=500M
#SBATCH --cpus-per-task=1
#SBATCH --time=01:00:00
#SBATCH --mem-per-cpu=1G
#SBATCH --cpus-per-task=4

MODE="tight"
if [ ! -z $1 ]; then
  MODE=$1
fi

#CASE_NUM=`printf %03d $SLURM_ARRAY_TASK_ID`
PROJ_DIR="${REPOS_DIR}/UnitCommitment2.jl"
INST=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${PROJ_DIR}/scripts/instances.txt)
#DEST="${PROJ_DIR}/benchmark"
DEST="${HOME}/scratch/uc"
RESULTS_DIR="${DEST}/results_${MODE}"
NUM_SAMPLES=1

if [ $MODE == "sparse" ] || [ $MODE == "default" ] || [ $MODE == "tight" ]
then
  echo "Running task $SLURM_ARRAY_TASK_ID for instance $INST with results sent to ${RESULTS_DIR}" 
else
  echo "Unrecognized mode: $1. Exiting."
  exit
fi

cd ${PROJ_DIR}/benchmark
mkdir -p $(dirname ${RESULTS_DIR}/${INST})
for i in $(seq ${NUM_SAMPLES}); do
  FILE=$INST.$i
  #echo "Running $FILE at `date` using command julia --project=${PROJ_DIR}/benchmark --sysimage=${PROJ_DIR}/build/sysimage.so ${PROJ_DIR}/benchmark/run.jl ${FILE} ${MODE} ${RESULTS_DIR} 2&>1 | cat > ${RESULTS_DIR}/${FILE}.log"
  #julia --project=${PROJ_DIR}/benchmark --sysimage=${PROJ_DIR}/build/sysimage.so ${PROJ_DIR}/benchmark/run.jl ${FILE} ${MODE} ${RESULTS_DIR} 2&>1 | cat > ${RESULTS_DIR}/${FILE}.log
  echo "Running $FILE at `date` using command julia --project=${PROJ_DIR}/benchmark --sysimage=${PROJ_DIR}/build/sysimage.so ${PROJ_DIR}/benchmark/run.jl ${FILE} ${MODE} ${RESULTS_DIR} &> ${RESULTS_DIR}/${FILE}.log"
  julia --project=${PROJ_DIR}/benchmark --sysimage=${PROJ_DIR}/build/sysimage.so ${PROJ_DIR}/benchmark/run.jl ${FILE} ${MODE} ${RESULTS_DIR} &> ${RESULTS_DIR}/${FILE}.log
  #julia --project=${PROJ_DIR}/benchmark --sysimage=${PROJ_DIR}/build/sysimage.so ${PROJ_DIR}/benchmark/run.jl ${FILE} ${MODE} ${RESULTS_DIR}
done
