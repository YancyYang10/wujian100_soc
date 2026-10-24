# tool path
export TOOL_PATH=/eda_tools/riscv-toolchain 
# lib path
export PROJ_HOME=$(pwd | sed -e 's/^\(.*\)\/verify\>.*/\1/')
#export PROJ_HOME=$(pwd | sed -e 's|^\(.*/dv\)/.*|\1|' -e 's|^\(.*/dv\)$|\1|')
echo $TOOL_PATH
echo $PROJ_HOME
