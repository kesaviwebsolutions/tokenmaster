// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBase.sol";

interface OwnableInterface {
    function owner() external returns (address);

    function transferOwnership(address recipient) external;

    function acceptOwnership() external;
}

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwnerWithProposal is OwnableInterface {
    address private s_owner;
    address private s_pendingOwner;

    event OwnershipTransferRequested(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed from, address indexed to);

    constructor(address newOwner, address pendingOwner) {
        require(newOwner != address(0), "Cannot set owner to zero");

        s_owner = newOwner;
        if (pendingOwner != address(0)) {
            _transferOwnership(pendingOwner);
        }
    }

    /**
     * @notice Allows an owner to begin transferring ownership to a new address,
     * pending.
     */
    function transferOwnership(address to) public override onlyOwner {
        _transferOwnership(to);
    }

    /**
     * @notice Allows an ownership transfer to be completed by the recipient.
     */
    function acceptOwnership() external override {
        require(msg.sender == s_pendingOwner, "Must be proposed owner");

        address oldOwner = s_owner;
        s_owner = msg.sender;
        s_pendingOwner = address(0);

        emit OwnershipTransferred(oldOwner, msg.sender);
    }

    /**
     * @notice Get the current owner
     */
    function owner() public view override returns (address) {
        return s_owner;
    }

    /**
     * @notice validate, transfer ownership, and emit relevant events
     */
    function _transferOwnership(address to) private {
        require(to != msg.sender, "Cannot transfer to self");

        s_pendingOwner = to;

        emit OwnershipTransferRequested(s_owner, to);
    }

    /**
     * @notice validate access
     */
    function _validateOwnership() internal view {
        require(msg.sender == s_owner, "Only callable by owner");
    }

    /**
     * @notice Reverts if called by anyone other than the contract owner.
     */
    modifier onlyOwner() {
        _validateOwnership();
        _;
    }
}

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwner is ConfirmedOwnerWithProposal {
    constructor(
        address newOwner
    ) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}

contract LotterySingle is ConfirmedOwner, VRFConsumerBase {
    using SafeERC20 for IERC20;

    enum LotteryStatus {
        OPEN,
        CLOSED,
        CANCELLED
    }

    address public platformWallet = 0xe34010A5cb2F412B4D17d034B4aEa9A29Ba9E024;

    uint256 public platformFee = 10; // 10% is fixed platform fees
    uint256 public creatorFee;

    uint256 public platformFeeAmount;
    uint256 public creatorFeeAmount;

    // Lottery parameters
    uint256 public lotteryDuration; // in seconds
    uint256 public minTicketsForRaffle;
    IERC20 public token;
    uint256 public ticketPrice;
    uint256 public maxTicketsPerWallet;
    uint256[] public shares;

    // Lottery state
    LotteryStatus public status;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public prizePot;
    uint256 public totalTicketsSold;
    address[] public participants;
    address[] public winners;
    mapping(address => uint256) public ticketsBought;
    bool public refundStatus;
    mapping(address => bool) public userRefunded;

    // Chainlink VRF fields
    bytes32 internal keyHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;
    uint256 internal fee = 5 * 10 ** 15; // 0.005 LINK

    event LotteryStatusChanged(LotteryStatus status);
    event ParticipantJoined(address participant);
    event PrizesDistributed();

    constructor(
        uint256 _startTime,
        uint256 _duration,
        IERC20 _token,
        uint256 _ticketPrice,
        uint8 _decimals,
        uint256 _maxTicketsPerWallet,
        uint256[] memory _shares,
        uint256 _creatorFee
    )
        VRFConsumerBase(
            0x6A2AAd07396B36Fe02a22b33cf443582f682c82f, // VRF Coordinator
            0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06 // LINK Token
        )
        ConfirmedOwner(tx.origin)
    {
        startTime = _startTime;
        lotteryDuration = _duration * 1 days;
        endTime = _startTime + lotteryDuration;
        token = _token;
        ticketPrice = _ticketPrice * 10**_decimals;
        maxTicketsPerWallet = _maxTicketsPerWallet;
        shares = _shares;

        status == LotteryStatus.OPEN;

        minTicketsForRaffle = _maxTicketsPerWallet * 10;
        
        creatorFee = _creatorFee;
    }

    function participate(uint256 _tickets) external {
        require(_tickets > 0, "Buy at least 1 ticket");
        require(status == LotteryStatus.OPEN, "Lottery not open");
        require(block.timestamp < endTime, "Lottery has ended");
        require(ticketsBought[msg.sender] + _tickets <= maxTicketsPerWallet, "Ticket limit exceeded");
        require(token.balanceOf(msg.sender) >= ticketPrice * _tickets, "Insufficient balance");

        uint256 totalValueAddingToPot = ticketPrice * _tickets;
        token.transferFrom(msg.sender, address(this), totalValueAddingToPot);
        for (uint256 i = 0; i < _tickets; i++) {
            participants.push(msg.sender);
        }

        ticketsBought[msg.sender] += _tickets;
        totalTicketsSold += _tickets;

        uint256 platformFeeAmntforTx = totalValueAddingToPot * platformFee / 100;
        uint256 creatorFeeAmountforTx = totalValueAddingToPot * creatorFee / 100;

        prizePot += totalValueAddingToPot - (platformFeeAmntforTx + creatorFeeAmountforTx);

        platformFeeAmount += platformFeeAmntforTx;
        creatorFeeAmount += creatorFeeAmountforTx;

        emit ParticipantJoined(msg.sender);

        // Check if the lottery should be automatically cancelled
        checkLotteryStatus();
    }

    function checkLotteryStatus() private {
        if (block.timestamp >= endTime) {
            if (totalTicketsSold < minTicketsForRaffle) {
                status = LotteryStatus.CANCELLED;
            } else {
                status = LotteryStatus.CLOSED;
            }
            emit LotteryStatusChanged(status);
        }
    }

    function drawWinners() external onlyOwner {
        require(status == LotteryStatus.CLOSED, "Lottery not closed");
        require(LINK.balanceOf(address(this)) >= fee, "Insufficient LINK");
        requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32, uint256 randomness) internal override {
        uint256 numParticipants = participants.length;
        require(numParticipants >= minTicketsForRaffle, "Not enough participants");

        uint256 numWinners = shares.length;
        for (uint256 i = 0; i < numWinners; i++) {
            uint256 index = randomness % numParticipants;
            winners.push(participants[index]);
            randomness = uint256(keccak256(abi.encode(randomness, i)));
        }

        distributePrizesAndFees();
    }

    function distributePrizesAndFees() internal {

        token.safeTransfer(platformWallet, platformFeeAmount);
        token.safeTransfer(owner(), creatorFeeAmount);

        uint256 totalDistributed = 0;
        for (uint256 i = 0; i < winners.length; i++) {
            uint256 winnerShare = (prizePot * shares[i]) / 100;
            token.safeTransfer(winners[i], winnerShare);
            totalDistributed += winnerShare;
        }

        if (prizePot > totalDistributed) {
            uint256 remainder = prizePot - totalDistributed;
            token.safeTransfer(owner(), remainder); // Returning the remainder to the owner or burn it
        }

        emit PrizesDistributed();
    }

    function cancelLottery() external onlyOwner {
        require(status == LotteryStatus.OPEN, "Lottery not open");
        status = LotteryStatus.CANCELLED;
        emit LotteryStatusChanged(status);
    }

    function claimRefund() external {
        require(status == LotteryStatus.CANCELLED, "Lottery not cancelled");
        require(!userRefunded[msg.sender], "Already refunded");
        uint256 amount = ticketsBought[msg.sender] * ticketPrice;
        require(amount > 0, "No tickets bought");

        userRefunded[msg.sender] = true;
        token.safeTransfer(msg.sender, amount);
    }
}
