// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from ReentrancyGuard will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single nonReentrant guard, functions marked as
 * nonReentrant may not call one another. This can be worked around by making
 * those functions private, and then adding external nonReentrant entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a nonReentrant function from another nonReentrant
     * function is not supported. It is possible to prevent this from happening
     * by making the nonReentrant function external, and make it call a
     * private function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

/// @title A contract for holding a fundraising project
/// @author Arrnaya (t.me/arrnaya)
contract BEATListings is Ownable, ERC20, ReentrancyGuard {
    IERC20 public stableCoin;

    uint256 public platformFee;
    address public platformWallet;

    uint256 public projectStartTime;
    uint256 public fundraisingGoal;
    uint256 public totalRaised;
    uint256 public totalSharesSold;
    uint256 public projectAPY; // Rate of return on investment
    uint256 public APYStartTime; // The reference time from when APY gets calculated

    uint256 public refundableShares;
    uint256 public totalAmountRefunded;
    uint256 public totalSharesAllocated;

    bool public isCancelled;
    bool public isFinished;
    bool public isFinalized;

    mapping(address => bool) public listedPlatforms;
    mapping(address => bool) public sharesClaimed;
    mapping(address => uint256) public returnClaimed;

    mapping(address => uint256) public addressToContributions;
    mapping(address => uint256) public investorToLastClaimTime;
    mapping(address => uint256) public investorClaimCount;
    mapping(address => uint256) public investorToShare;
    mapping(address => uint256) public addressToMintedTokens;

    uint256 public contributionAmnt;
    uint256 public maxAllowedSharesPerWallet;

    event Contribution(
        address indexed from, address indexed project, uint256 amount
    );
    event SharesClaimed(address to, uint256 amount);
    event Refund(address indexed to, address indexed project, uint256 amount);
    event Withdraw(address indexed to, address indexed project, uint256 amount);
    event ListingFinalized(uint256 timestamp);
    event ReturnClaimed(address investor, uint256 claimedAmount);
    event AnnualAPRDeposited(uint256 depositAmount);

    // constructor (IERC20 _stableCoin) {
    //   stableCoin = _stableCoin;
    // }

    modifier isNotCancelledProject() {
        require(!isCancelled, "Project: project is cancelled");
        _;
    }

    modifier hasReachedSoftCap() {
        require(
            totalRaised >= fundraisingGoal / 2,
            "Project: Project has not reached SoftCap yet."
        );
        _;
    }

    modifier hasNotReachedSoftCap() {
        require(
            totalRaised < fundraisingGoal / 2,
            "Project: Project has reached SoftCap already."
        );
        _;
    }

    modifier raiseSuccessful() {
        require(
            totalRaised >= fundraisingGoal, "Project: Fund raise in progress."
        );
        _;
    }

    modifier raiseInProgress() {
        require(
            totalRaised < fundraisingGoal,
            "Project: Funds have been raised successfully."
        );
        _;
    }

    modifier isNotFinishedProject() {
        require(!isFinished, "Project: project has finished");
        _;
    }

    modifier onlyWhitelisted() {
        require(
            listedPlatforms[msg.sender],
            "WhitelistedERC20: caller is not whitelisted"
        );
        _;
    }

    /// @notice Instantiates a new fundraising project and instantly transfers ownership
    /// to the _projectOwner address provided
    /// @param _name The name of the fundraising project to be used in the NFT badges
    /// given to contributors of >= 1 ether
    /// @param _symbol The NFT token symbol
    /// @param _fundraisingGoal The total ether goal of the new fundraising project
    /// @param _projectOwner The true owner of the project (and which instantly gains
    /// ownership on completion of instantiating the contract)
    /// @dev The project expiration time will always be 30 days from creation
    constructor(
        IERC20 _stableCoin,
        string memory _name,
        string memory _symbol,
        uint256 _fundraisingGoal,
        uint256 _contributionAmnt,
        uint256 _projectStartTime,
        uint256 _maxSharesPerWallet,
        address _projectOwner,
        uint256 _platformFee,
        address _platformWallet,
        uint256 _projectAPY
    ) ERC20(_name, _symbol) {
        require(address(_stableCoin) != address(0), "Can't set zero address");
        stableCoin = _stableCoin;
        transferOwnership(_projectOwner);
        fundraisingGoal = _fundraisingGoal;
        contributionAmnt = _contributionAmnt;
        maxAllowedSharesPerWallet = _maxSharesPerWallet;
        projectStartTime = _projectStartTime;
        platformFee = _platformFee;
        platformWallet = _platformWallet;
        projectAPY = _projectAPY;

        listedPlatforms[address(this)] = true;

        _transferOwnership(tx.origin);
    }

    // fallbacks
    receive() external payable {}

    /// @notice Allows any address to contribute to the contract if the project has not
    /// been cancelled, is not expired, and has not already been finished successfully
    /// @dev If an address' contributions put the contract over or equal the fundraising limit,
    /// it's a valid contribution but the fundraising project is finished immediately
    function _participate(uint256 _numberOfShares)
        external
        isNotCancelledProject
        raiseInProgress
        isNotFinishedProject
        nonReentrant
    {
        require(
            _numberOfShares > 0 && _numberOfShares <= maxAllowedSharesPerWallet,
            "Shares can't be less than zero and more than max allowed"
        );
        require(
            (contributionAmnt * _numberOfShares)
                + stableCoin.balanceOf(address(this)) <= fundraisingGoal,
            "Exceeding total fund raising goal!"
        );
        require(
            investorToShare[msg.sender] + _numberOfShares
                <= maxAllowedSharesPerWallet,
            "Can't buy more than the max share allowed!"
        );

        uint256 _finalContributionAmnt = contributionAmnt * _numberOfShares;

        if (
            (contributionAmnt * _numberOfShares)
                + stableCoin.balanceOf(address(this)) >= fundraisingGoal
        ) {
            isFinished = true;
        }

        stableCoin.transferFrom(
            msg.sender, address(this), _finalContributionAmnt
        );

        //mapping contribution amount to investor address
        addressToContributions[msg.sender] += _finalContributionAmnt;
        // Mapping shares to the investor address
        investorToShare[msg.sender] += _numberOfShares;
        // Mapping total raised & total shares sold
        totalRaised += _finalContributionAmnt;
        totalSharesSold += _numberOfShares;

        emit Contribution(msg.sender, address(this), _finalContributionAmnt);
    }

    function _claimShares() external isNotCancelledProject nonReentrant {
        require(isFinalized, "Project: Sale is not finished yet!");
        require(
            !sharesClaimed[msg.sender],
            "Project: Shares have already been claimed for this wallet."
        );
        require(
            investorToShare[msg.sender] > 0,
            "Project: address has no contributions"
        );
        // Mints nft to the contributor's address
        uint256 sharedAllocatedToInvestor =
            investorToShare[msg.sender] * 10 ** decimals();

        // Mapping NFT Balance to the investor address
        addressToMintedTokens[msg.sender] += sharedAllocatedToInvestor;

        sharesClaimed[msg.sender] = true;

        _mint(msg.sender, sharedAllocatedToInvestor);

        totalSharesAllocated += sharedAllocatedToInvestor;

        emit SharesClaimed(msg.sender, sharedAllocatedToInvestor);
    }

    /// @notice Allows the owner of the project to cancel it if the project has not
    /// been cancelled, is not expired, and has not already been finished successfully
    function cancel_Project()
        external
        onlyOwner
        isNotCancelledProject
        hasNotReachedSoftCap
        isNotFinishedProject
    {
        isCancelled = true;
        refundableShares = totalSharesSold;
    }

    /// @notice Refunds an address' funds if the project is either cancelled or has
    /// expired without finishing successfully
    function _claim_Refund_on_cancellation()
        external
        nonReentrant
        hasNotReachedSoftCap
    {
        require(isCancelled, "Project: cannot refund project funds");
        require(
            addressToContributions[msg.sender] > 0,
            "Project: address has no contributions"
        );
        require(
            refundableShares > 0
                && stableCoin.balanceOf(address(this))
                    >= addressToContributions[msg.sender],
            "No shares remaining for refund"
        );

        uint256 addressContributions = addressToContributions[msg.sender];
        totalAmountRefunded += addressContributions;
        addressToContributions[msg.sender] = 0;
        totalSharesSold -= investorToShare[msg.sender];
        refundableShares -= investorToShare[msg.sender];
        investorToShare[msg.sender] = 0;

        stableCoin.transfer(msg.sender, addressContributions);

        emit Refund(msg.sender, address(this), addressContributions);
    }

    function finalize() external onlyOwner hasReachedSoftCap {
        processFunds(msg.sender);
        isFinalized = true;

        APYStartTime = block.timestamp;

        emit ListingFinalized(block.timestamp);
    }

    /// @notice Allows the owner of the contract to withdraw a successfully completed
    /// fundraising project's ether
    function processFunds(address _owner) internal {
        require(isFinished, "Project: project is not finished");

        uint256 annualReturnAmount = (totalRaised * projectAPY) / 100;
        uint256 platformFeeAmount = (totalRaised * platformFee) / 100;
        uint256 listingTransferAmount =
            totalRaised - annualReturnAmount - platformFeeAmount;

        stableCoin.transfer(platformWallet, platformFeeAmount);
        stableCoin.transfer(_owner, listingTransferAmount);
        emit Withdraw(_owner, address(this), listingTransferAmount);
    }

    function recoverETH() external onlyOwner {
        require(address(this).balance > 0, "Nothing to recover");
        payable(msg.sender).transfer(address(this).balance);
    }

    function claimReturn() external {
        require(isFinalized, "Project: Sale is not finished yet!");
        require(
            investorToShare[msg.sender] > 0,
            "Project: address has no contributions"
        );
        uint256 eligibleCalls = (block.timestamp - APYStartTime) / 1800; // change to 30 days for production
        require(
            eligibleCalls > investorClaimCount[msg.sender],
            "You have already claimed for this period or it is not yet time."
        );

        uint256 missedCalls = eligibleCalls - investorClaimCount[msg.sender];
        investorClaimCount[msg.sender] = eligibleCalls; // Update call count to the current eligible period

        // Multiply missedCalls with the amount they can claim each period
        for (uint256 i = 0; i < missedCalls; i++) {
            processClaim(msg.sender);
        }
    }

    function processClaim(address _investor) internal {
        uint256 claimAmount = calculateClaimableAPYForInvestor(_investor);

        returnClaimed[_investor] = claimAmount;
        if (stableCoin.balanceOf(address(this)) < claimAmount) {
            stableCoin.transferFrom(
                owner(), address(this), (totalRaised * projectAPY) / 100
            );
        }
        stableCoin.transfer(_investor, claimAmount);

        emit ReturnClaimed(_investor, claimAmount);
    }

    function calculateClaimableAPYForInvestor(address _investor)
        public
        view
        returns (uint256)
    {
        // require(
        //     investorToShare[_investor] > 0, "Project: address has no shares"
        // );

        uint256 duration;

        if (investorToLastClaimTime[_investor] == 0) {
            duration = block.timestamp - APYStartTime;
        } else {
            duration = block.timestamp - investorToLastClaimTime[_investor];
        }

        uint256 returnAmount = (
            investorToShare[_investor] * contributionAmnt * projectAPY
                * duration
        ) / (365 * 100 * 86400);

        return returnAmount;
    }

    function rescueERC20(address tokenAdd) external onlyOwner {
        require(
            IERC20(tokenAdd) != stableCoin,
            "Can't claim fund raising tokens using this method!"
        );
        uint256 amount = IERC20(tokenAdd).balanceOf(address(this));
        IERC20(tokenAdd).transfer(owner(), amount);
    }

    function depositAPR() external onlyOwner {
        uint256 depositAmount = (totalRaised * projectAPY) / 100;
        stableCoin.transferFrom(msg.sender, address(this), depositAmount);

        emit AnnualAPRDeposited(depositAmount);
    }

    function listPlatform(address platform) public onlyOwner {
        require(platform != address(0), "Can't set to zero address");
        listedPlatforms[platform] = true;
    }

    function removeListedPlatform(address platform) public onlyOwner {
        require(platform != address(0), "Can't set to zero address");
        listedPlatforms[platform] = false;
    }

    function _transfer(address from, address to, uint256 amount)
        internal
        override
        onlyWhitelisted
    {
        investorToShare[from] -= amount;
        investorToShare[to] += amount;

        super._transfer(from, to, amount);
    }
}
