.PHONY: test build clean format lint

test:
	forge test -vvv

coverage:
	forge coverage --report lcov

build:
	forge build

clean:
	forge clean

format:
	forge fmt

lint:
	solhint 'src/**/*.sol'

gas:
	forge test --gas-report
