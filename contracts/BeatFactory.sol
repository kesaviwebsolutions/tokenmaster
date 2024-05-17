// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./BEATListings.sol";

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing MAAL721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

contract BEATFactory is Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _counter;

    uint256 public platformFee = 20; // 20%
    address public platformWallet = 0xcc4Ef3FC58Aa1EE91626f50037734b5f3cA1358a;

    address public DOTB;

    address[] public contractsList;

    event ProjectCreated(address listing);
    event PlatformFeeUpdated(uint256 fee);
    event PlatformWalletUpdated(address wallet);

    mapping(address => address[]) private ListedProjects;

    // mapping(uint256 => address) public indexToOwner; //index to NFT owner address

    constructor() {
        DOTB = msg.sender;
    }

    function createListing(
        IERC20 _stableCoin,
        string memory _name,
        string memory _projectSymbol,
        uint256 _fundraisingGoal,
        uint256 _contributionAmnt,
        uint256 _projectStartTime,
        uint256 _maxSharesPerWallet,
        address _projectOwner,
        uint256 _projectAPY
    ) external onlyOwner returns (address newProjectAddress) {
        BEATListings newProject = new BEATListings(
        _stableCoin,
        _name,
        _projectSymbol,
        _fundraisingGoal,
        _contributionAmnt,
        _projectStartTime,
        _maxSharesPerWallet,
        _projectOwner,
        platformFee,
        platformWallet,
        _projectAPY
        );
        contractsList.push(address(newProject));
        _counter.increment();

        // Mapping NFT IDs to the investor address
        ListedProjects[msg.sender].push(address(newProject));

        emit ProjectCreated(address(newProject));
        return address(newProject);
    }

    function deployedCounter() public view returns (uint256 __counter) {
        return _counter.current();
    }

    function deployedContracts() public view returns (address[] memory) {
        return contractsList;
    }

    // Return all NFT addresses held by an address
    function getUserProjects(address deployer)
        external
        view
        returns (address[] memory contracts)
    {
        address[] memory arr = ListedProjects[deployer];
        return arr;
    }

    function modifyPlatformFee(uint256 _platformFee) external onlyOwner {
        platformFee = _platformFee;

        emit PlatformFeeUpdated(_platformFee);
    }

    function updatePlatformWallet(address _newWallet) external {
        require(msg.sender == DOTB, "only DOTB can update");

        platformWallet = _newWallet;

        emit PlatformWalletUpdated(_newWallet);
    }
}
