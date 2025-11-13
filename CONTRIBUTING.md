# Contributing to SubBase

Thank you for your interest in contributing!

## Development Setup

1. Install Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Clone and install dependencies
```bash
git clone https://github.com/yourusername/SubBase
cd SubBase
forge install
```

3. Run tests
```bash
forge test
```

## Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## Coding Standards

- Follow Solidity style guide
- Add NatSpec comments
- Write comprehensive tests
- Maintain gas efficiency
- Use custom errors over require strings

## Commit Messages

Use conventional commits:
- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation
- `test:` Tests
- `refactor:` Code refactoring
- `chore:` Maintenance

## Questions?

Open an issue for discussion before major changes.
