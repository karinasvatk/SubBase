.PHONY: test build deploy clean

test:
	forge test -vvv

test-coverage:
	forge coverage --report lcov

build:
	forge build

deploy-sepolia:
	forge script script/Deploy.s.sol:DeployScript --rpc-url $(BASE_SEPOLIA_RPC) --broadcast --verify

deploy-mainnet:
	forge script script/Deploy.s.sol:DeployScript --rpc-url $(BASE_MAINNET_RPC) --broadcast --verify

upgrade:
	forge script script/Upgrade.s.sol:UpgradeScript --rpc-url $(BASE_MAINNET_RPC) --broadcast --verify

clean:
	forge clean

format:
	forge fmt

lint:
	solhint 'src/**/*.sol'

gas-report:
	forge test --gas-report
