export DEPLOYER=0x....
export RPC_URL=https://virtual.avalanche.rpc.tenderly.co/....
#export RPC_URL=http://127.0.0.1:8545


forge script script/DeploySimple.s.sol --chain-id 43114 --rpc-url $RPC_URL $1 $2 $3 $4


