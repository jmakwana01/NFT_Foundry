# MyNFT - Comprehensive ERC721 Contract with Foundry

A feature-rich ERC721 NFT contract built for learning Foundry, with comprehensive testing and documentation. This project demonstrates advanced Solidity patterns, testing strategies, and Foundry workflows.

## 🚀 Features

### Core Functionality
- **ERC721 Standard**: Full compliance with ERC721 specification
- **Enumerable**: Track and iterate through all tokens
- **URI Storage**: Individual token URIs with fallback to base URI
- **Pausable**: Emergency pause mechanism for all transfers and mints
- **Access Control**: Role-based permissions (Admin, Minter, Pauser)
- **Ownable**: Contract ownership with transfer capabilities

### Advanced Features
- **Public Minting**: Paid minting for general public
- **Whitelist Minting**: Special access for whitelisted addresses
- **Batch Minting**: Gas-efficient bulk minting for admins
- **Supply Cap**: Maximum supply limit (10,000 tokens)
- **Per-wallet Limits**: Maximum 5 tokens per wallet for public mint
- **Royalty Support**: EIP-2981 compliant royalty system
- **Reentrancy Protection**: Secure against reentrancy attacks

## 📁 Project Structure

```
├── src/
│   └── MyNFT.sol              # Main NFT contract
├── test/
│   └── MyNFT.t.sol            # Comprehensive test suite
├── script/
│   └── Deploy.s.sol           # Deployment script
├── foundry.toml               # Foundry configuration
├── Makefile                   # Build and deployment commands
└── README.md                  # This file
```

## 🛠️ Setup

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/downloads)

### Installation

1. **Clone and setup the project:**
```bash
# Initialize new Foundry project (if starting fresh)
forge init my-nft-project
cd my-nft-project

# Install dependencies
make install
# or manually:
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std
```

2. **Build the project:**
```bash
make build
# or
forge build
```

3. **Run tests:**
```bash
make test
# or
forge test -vv
```

## 🧪 Testing

This project includes comprehensive tests covering:

### Test Categories
- ✅ **Unit Tests**: Individual function testing
- ✅ **Integration Tests**: Full workflow testing
- ✅ **Edge Cases**: Boundary conditions and error scenarios
- ✅ **Access Control**: Permission and role testing
- ✅ **Fuzz Tests**: Property-based testing with random inputs
- ✅ **Gas Optimization**: Performance benchmarking

### Test Commands

```bash
# Run all tests with verbose output
make test

# Run with maximum verbosity (shows traces)
make test-verbose

# Run specific test
make test-specific TEST=test_PublicMint_Success

# Run fuzz tests with more iterations
make test-fuzz

# Generate coverage report
make test-coverage

# Generate HTML coverage report
make test-coverage-html

# Test with gas reporting
make test-gas

# Take gas snapshot
make gas-snapshot
```

### Test Coverage
The test suite aims for 100% code coverage including:
- All functions and modifiers
- All conditional branches
- All error conditions
- All events emission
- All access control scenarios

## 🚀 Deployment

### Local Development

```bash
# Start local Anvil node
make anvil

# Deploy to local network
make deploy-local
```

### Testnet Deployment

```bash
# Set environment variables
export PRIVATE_KEY=0x...
export RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
export ETHERSCAN_API_KEY=YOUR_API_KEY

# Deploy to testnet
make deploy-testnet NETWORK=sepolia RPC_URL=$RPC_URL ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY
```

### Environment Variables
Create a `.env` file (never commit this):
```env
PRIVATE_KEY=0x...
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
NFT_NAME="My NFT Collection"
NFT_SYMBOL="MNC"
NFT_BASE_URI="https://api.mynft.com/metadata/"
```

## 🎯 Contract Usage

### Basic Minting Flow

1. **Deploy Contract:**
```solidity
MyNFT nft = new MyNFT("My Collection", "MC", "https://api.example.com/", owner);
```

2. **Setup Access (Owner only):**
```solidity
// Grant minter role
nft.grantRole(nft.MINTER_ROLE(), minterAddress);

// Enable public minting
nft.setPublicMintEnabled(true);

// Set mint price
nft.setMintPrice(0.01 ether);
```

3. **Public Minting:**
```solidity
// User mints a token
nft.publicMint{value: 0.01 ether}(userAddress);
```

4. **Admin Minting:**
```solidity
// Minter role can mint with custom URI
nft.mintWithURI(recipient, "ipfs://custom-hash");

// Batch mint to multiple addresses
address[] memory recipients = [addr1, addr2, addr3];
nft.batchMint(recipients);
```

### Key Functions

#### Public Functions
- `publicMint(address to)` - Public paid minting
- `whitelistMint(address to)` - Whitelist minting
- `tokenURI(uint256 tokenId)` - Get token metadata URI
- `royaltyInfo(uint256, uint256)` - Get royalty information

#### Admin Functions (Owner only)
- `setBaseURI(string memory)` - Update base URI
- `setMintPrice(uint256)` - Update mint price
- `setPublicMintEnabled(bool)` - Toggle public minting
- `addToWhitelist(address[])` - Add addresses to whitelist
- `withdraw()` - Withdraw contract funds
- `pause()/unpause()` - Emergency controls

#### Minter Role Functions
- `mintWithURI(address, string)` - Mint with custom URI
- `batchMint(address[])` - Batch mint tokens

## 📊 Gas Optimization

The contract is optimized for gas efficiency:

- **No Counters Library**: Uses simple uint256 increment
- **Batch Operations**: Efficient bulk minting
- **Packed Storage**: Optimized storage layout
- **Custom Errors**: Gas-efficient error handling

### Gas Benchmarks
Run `make test-gas` to see current gas usage for each function.

## 🔒 Security Features

- **Reentrancy Protection**: OpenZeppelin's ReentrancyGuard
- **Access Control**: Role-based permissions
- **Pausable**: Emergency stop mechanism
- **Supply Limits**: Maximum supply and per-wallet caps
- **Input Validation**: Comprehensive parameter checking

## 🔍 Code Quality

### Static Analysis
```bash
# Install slither
pip install slither-analyzer

# Run analysis
make analyze
```

### Code Formatting
```bash
# Format code
make fmt

# Check formatting
make fmt-check
```

### Documentation
```bash
# Generate docs
make doc

# Serve docs locally
make doc-serve
```

## 📈 Advanced Usage

### Fuzz Testing Examples

The test suite includes comprehensive fuzz testing:

```solidity
function testFuzz_SetMintPrice(uint256 price) public {
    price = bound(price, 0, 100 ether);
    vm.prank(owner);
    nft.setMintPrice(price);
    assertEq(nft.mintPrice(), price);
}
```

### Invariant Testing

For more advanced testing, consider adding invariant tests:

```solidity
// Example invariant: Total supply should never exceed MAX_SUPPLY
function invariant_totalSupplyNeverExceedsMax() public {
    assertLe(nft.totalSupply(), nft.MAX_SUPPLY());
}
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Add comprehensive tests
4. Ensure all tests pass
5. Update documentation
6. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🎓 Learning Resources

This project is designed for learning Foundry. Key concepts covered:

- **Contract Architecture**: Multiple inheritance patterns
- **Testing Strategies**: Unit, integration, and fuzz testing
- **Access Control**: OpenZeppelin's AccessControl system
- **Gas Optimization**: Efficient Solidity patterns
- **Security**: Best practices and vulnerability prevention
- **Deployment**: Scripts and environment management

## 🔗 Useful Links

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Documentation](https://docs.openzeppelin.com/)
- [ERC721 Standard](https://eips.ethereum.org/EIPS/eip-721)
- [Solidity Documentation](https://docs.soliditylang.org/)

---

**Happy Learning! 🚀**

*This project demonstrates real-world Solidity development patterns and comprehensive testing strategies using Foundry.*# NFT_Foundry
