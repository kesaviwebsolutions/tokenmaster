// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

contract Lottery is ConfirmedOwner, VRFConsumerBase {
    using SafeERC20 for IERC20;
    enum LotteryStatus {
        OPEN,
        CLOSED,
        CANCELLED
    }

    uint256 public lotteryDuration; // in number of days
    uint256 public minTicketsForRaffle; // minimum number of tickets to be sold for the raffle to take place
    IERC20 public token; // token to buy lottery ticket
    uint256 public ticketPrice; // ticket price per token in tokens in wei
    uint256 public maxTicketsPerWallet; // Max number of tickets that can be bought by a wallet
    uint256 public numWinners; // number of winners that can be picked

    uint256 public progressivePoolValue;
    uint256 public totalTicketsBought;

    bytes32 internal keyHash =
        0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;
    uint256 internal fee = 5 * 10 ** 15; // 0.005 LINK
    mapping(bytes32 => uint256) public requestIdToLotteryId;

    bool initialized;
    bool locked;
    bool paused;

    struct LotteryData {
        LotteryStatus status;
        uint256 startTime;
        uint256 endTime;
        uint256 prizePot;
        address[] participants;
        address[] winners;
        uint256[] shares; // Shares of winners
    }

    mapping(uint256 => bool) public refundStatus;
    mapping(uint256 => mapping(address => bool)) public userRefunded;

    uint256 public currentLotteryId = 0;

    mapping(uint256 => LotteryData) private lotteries;
    mapping(uint256 => mapping(address => uint256)) public ticketsBought;
    mapping(uint256 => bool) private numberUsed;

    event LotteryOpened(uint256 id);
    event LotteryClosed(uint256 id);
    event LotteryCancelled(uint256 id);
    event ParticipantJoined(uint256 lotteryId, address participant);
    event PrizesDistributed(uint256 lotteryId);

    constructor(
        uint256 _duration,
        IERC20 _token,
        uint256 _ticketPrice,
        uint8 _decimals,
        uint256 _maxTicketsPerWallet,
        uint256[] memory _shares
    )
        VRFConsumerBase(
            0x6A2AAd07396B36Fe02a22b33cf443582f682c82f, // VRF Coordinator
            0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06 // LINK Token
        )
        ConfirmedOwner(msg.sender)
    {
        initialize(
            _duration,
            _token,
            _ticketPrice,
            _decimals,
            _maxTicketsPerWallet,
            _shares
        );

        minTicketsForRaffle = _maxTicketsPerWallet * 10;
        lockValues();
    }

    function initialize(
        uint256 _duration,
        IERC20 _token,
        uint256 _ticketPrice,
        uint8 _decimals,
        uint256 _maxTicketsPerWallet,
        uint256[] memory _shares
    ) internal {
        require(!initialized, "Error: Contract is already initialized");
        require(
            _duration > 0 && _maxTicketsPerWallet > 0 && _decimals > 0,
            "Error: Can't set to zero value"
        );
        require(
            _token != IERC20(address(0)),
            "Error: Can't set to zero address"
        );
        require(_shares.length <= 10, "Too many winners");

        uint256 totalShare = 0;
        for (uint256 i = 0; i < _shares.length; i++) {
            totalShare += _shares[i];
        }
        require(totalShare == 100, "Total shares must sum to 100%");

        lotteryDuration = _duration * 1 days;
        token = _token;
        ticketPrice = _ticketPrice * 10 ** _decimals; // change to wei
        maxTicketsPerWallet = _maxTicketsPerWallet;
        lotteries[currentLotteryId].shares = _shares;

        initialized = true;
    }

    function lockValues() internal {
        require(initialized, "Error: Contract is not yet initialized");
        require(!locked, "Error: Already locked");

        locked = true;
    }

    function fetchLotteryData(
        uint256 lotteryId
    )
        external
        view
        returns (
            LotteryStatus status,
            uint256 startTime,
            uint256 endTime,
            uint256 prizePot,
            address[] memory participants,
            address[] memory winners,
            uint256[] memory shares
        )
    {
        require(lotteryId <= currentLotteryId, "Lottery does not exist");
        LotteryData storage lottery = lotteries[lotteryId];
        return (
            lottery.status,
            lottery.startTime,
            lottery.endTime,
            lottery.prizePot,
            lottery.participants,
            lottery.winners,
            lottery.shares
        );
    }

    function participate(uint256 _tickets) external {
        require(_tickets > 0, "Error: Buy at least 1 ticket");
        require(initialized && !paused, "Error: Not open!");
        require(
            ticketsBought[currentLotteryId][msg.sender] + _tickets <=
                maxTicketsPerWallet,
            "Error: Can't buy more tickets than max allowed per wallet"
        );

        if (block.timestamp >= lotteries[currentLotteryId].endTime) {
            closeLottery();
        }

        if (
            block.timestamp >= lotteries[currentLotteryId].endTime &&
            totalTicketsBought < minTicketsForRaffle
        ) {
            cancelLottery();
        }

        require(
            lotteries[currentLotteryId].status == LotteryStatus.OPEN,
            "Error: Lottery is not open"
        );
        require(
            token.balanceOf(msg.sender) >= ticketPrice * _tickets,
            "Error: Must have enough balance to buy tickets"
        );
        require(
            token.transferFrom(
                msg.sender,
                address(this),
                ticketPrice * _tickets
            ),
            "Error: Transfer failed"
        );

        // Add user address based on number of tickets
        for (uint256 i = 0; i < _tickets; i++) {
            lotteries[currentLotteryId].participants.push(msg.sender);
        }

        ticketsBought[currentLotteryId][msg.sender] += _tickets;
        lotteries[currentLotteryId].prizePot += ticketPrice * _tickets;

        progressivePoolValue += ticketPrice * _tickets;

        emit ParticipantJoined(currentLotteryId, msg.sender);
    }

    function closeLottery() internal {
        require(
            lotteries[currentLotteryId].status == LotteryStatus.OPEN,
            "Error: Lottery already closed"
        );
        require(
            block.timestamp >= lotteries[currentLotteryId].endTime,
            "Error: Wait for lottery to end"
        );

        lotteries[currentLotteryId].status = LotteryStatus.CLOSED;

        emit LotteryClosed(currentLotteryId);
    }

    function cancelLottery() internal {
        lotteries[currentLotteryId].status = LotteryStatus.CANCELLED;

        emit LotteryCancelled(currentLotteryId);
    }

    function requestRandomnessForLottery(uint256 lotteryId) external onlyOwner {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK to pay fee"
        );
        bytes32 requestId = requestRandomness(keyHash, fee);
        requestIdToLotteryId[requestId] = lotteryId;
    }

    function fulfillRandomness(
        bytes32 requestId,
        uint256 randomness
    ) internal override {
        uint256 lotteryId = requestIdToLotteryId[requestId];
        pickWinnersAndDistribute(lotteryId, randomness);
    }

    function pickWinnersAndDistribute(
        uint256 lotteryId,
        uint256 randomness
    ) internal {
        LotteryData storage lottery = lotteries[lotteryId];
        require(lottery.status == LotteryStatus.OPEN, "Lottery not open");

        uint256 maxWinners = lottery.shares.length;
        address[] memory tempWinners = new address[](maxWinners);
        uint256 actualWinnersCount = 0;

        for (
            uint256 i = 0;
            i < maxWinners && actualWinnersCount < maxWinners;
            i++
        ) {
            uint256 randomIndex = randomness % lottery.participants.length;
            address selectedWinner = lottery.participants[randomIndex];
            // Ensure no duplicates in winners
            bool isDuplicate = false;
            for (uint256 j = 0; j < actualWinnersCount; j++) {
                if (tempWinners[j] == selectedWinner) {
                    isDuplicate = true;
                    break;
                }
            }
            if (!isDuplicate) {
                tempWinners[actualWinnersCount++] = selectedWinner;
            }
            // Update randomness
            randomness = uint256(keccak256(abi.encode(randomness, i)));
        }

        // Copy to correctly sized array
        address[] memory winners = new address[](actualWinnersCount);
        for (uint256 i = 0; i < actualWinnersCount; i++) {
            winners[i] = tempWinners[i];
        }

        lottery.winners = winners;
        distributePrizes(lotteryId);
    }

    function distributePrizes(uint256 lotteryId) internal {
        require(
            lotteries[lotteryId].status == LotteryStatus.CLOSED,
            "Lottery is not closed"
        );

        LotteryData storage lottery = lotteries[lotteryId];
        uint256 prizePot = lottery.prizePot;
        uint256 totalDistributed = 0;

        // Calculate and distribute prizes based on the shares for each winner
        for (uint256 i = 0; i < lottery.winners.length; i++) {
            uint256 prize = (prizePot * lottery.shares[i]) / 100;
            token.safeTransfer(lottery.winners[i], prize);
            totalDistributed += prize;
        }

        // Handle any remaining funds due to rounding errors
        uint256 remaining = prizePot - totalDistributed;
        if (remaining > 0) {
            // Optionally redistribute the remaining funds or send them to a specific account
            // For example, adding to the prize pot of the next lottery or sending to a burn address
            token.safeTransfer(address(0xdead), remaining); // Burn the remaining tokens
        }

        emit PrizesDistributed(lotteryId);
    }

    function claimRefund() external {
        require(
            lotteries[currentLotteryId].status == LotteryStatus.CANCELLED,
            "Lottery must be cancelled to claim refund"
        );
        require(refundStatus[currentLotteryId], "Error: not in refund mode.");
        require(
            !userRefunded[currentLotteryId][msg.sender],
            "Error: already refunded"
        );

        if (ticketsBought[currentLotteryId][msg.sender] > 0) {
            userRefunded[currentLotteryId][msg.sender] = true;
            uint256 refundAmount = ticketsBought[currentLotteryId][msg.sender] *
                ticketPrice;
            token.transfer(msg.sender, refundAmount);
        } else {
            revert("No refund to claim");
        }
    }
}
