// Sources flattened with hardhat v2.1.2 https://hardhat.org

// File contracts/Airdrop.sol

pragma solidity ^0.8.0;

interface ILYD {
    function balanceOf(address account) external view returns (uint);

    function transfer(address dst, uint rawAmount) external returns (bool);
}

/**
 *  Contract for administering the Airdrop of LYD. 16_200_000 LYD will be
 *  made available in the airdrop. After the Airdrop period is over, all
 *  unclaimed LYD will be transferred to the dead account and burnt.
 */
contract Airdrop {
    // the token address
    address public lyd;

    address public owner;

    // amount of LYD to transfer
    mapping(address => uint96) public withdrawAmount;

    mapping(address => bool) public checkList;

    uint public totalAllocated;

    bool public claimingAllowed;

    uint constant public TOTAL_AIRDROP_SUPPLY = 16_200_000e18;

    address constant public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // Events
    event ClaimingAllowed();
    event ClaimingOver();
    event LydClaimed(address claimer, uint amount);

    /**
     * Initializes the contract. Sets token address and owner.
     * Claiming period is not enabled.
     *
     * @param lyd_ the LYD token contract address
     * @param owner_ the privileged contract owner
     */
    constructor(address lyd_, address owner_)  {
        lyd = lyd_;
        owner = owner_;
        claimingAllowed = false;
        totalAllocated = 0;
    }

    /**
     * Changes the contract owner. Can only be set by the contract owner.
     *
     * @param owner_ new contract owner address
     */
    function setOwner(address owner_) external {
        require(msg.sender == owner, 'Airdrop::setowner: unauthorized');
        owner = owner_;
    }

    /**
     * Enable the claiming period and allow users to claim LYD. Before activation,
     * this contract must have a LYD balance equal to the total airdrop LYD
     * supply of 16.2 million LYD. Claimable LYD tokens must be whitelisted
     * before claiming is enabled. Only callable by the owner.
     */
    function allowClaiming() external {
        require(ILYD(lyd).balanceOf(address(this)) >= TOTAL_AIRDROP_SUPPLY, 'Airdrop::allowClaiming: incorrect LYD supply');
        require(msg.sender == owner, 'Airdrop::allowClaiming: unauthorized');
        claimingAllowed = true;
        emit ClaimingAllowed();
    }

    /**
     * End the claiming period. All unclaimed LYD will be burnt.
     * Can only be called by the owner.
     */
    function endClaiming() external {
        require(msg.sender == owner, 'Airdrop::endClaiming: unauthorized');
        require(claimingAllowed, "Airdrop::endClaiming: Claiming not started");

        claimingAllowed = false;
        emit ClaimingOver();

        // Burn remainder
        uint amount = ILYD(lyd).balanceOf(address(this));
        require(ILYD(lyd).transfer(BURN_ADDRESS, amount), 'Airdrop::endClaiming: Transfer failed');
    }

    /**
     * Withdraw your LYD. In order to qualify for a withdrawal, the caller's address
     * must be whitelisted. Only the full amount can be claimed and only one claim is
     * allowed per user.
     */
    function claim() external {
        require(claimingAllowed, 'Airdrop::claim: Claiming is not allowed');
        require(withdrawAmount[msg.sender] > 0, 'Airdrop::claim: No LYD to claim');

        uint amountToClaim = withdrawAmount[msg.sender];
        withdrawAmount[msg.sender] = 0;

        emit LydClaimed(msg.sender, amountToClaim);

        require(ILYD(lyd).transfer(msg.sender, amountToClaim), 'Airdrop::claim: Transfer failed');
    }

    /**
     * Whitelist an address to claim LYD. Specify the amount of LYD to be allocated.
     * That address will then be able to claim that amount of LYD during the claiming
     * period. The transferable amount of LYD must be nonzero. Total amount allocated
     * must be less than or equal to the total airdrop supply. Whitelisting must occur
     * before the claiming period is enabled. Addresses may only be added one time.
     * Only called by the owner.
     *
     * @param addr address that may claim LYD
     * @param lydOut the amount of LYD that addr may withdraw
     */
    function whitelistAddress(address addr, uint96 lydOut) public {
        require(msg.sender == owner, 'Airdrop::whitelistAddress: unauthorized');
        require(lydOut > 0, 'Airdrop::whitelistAddress: No LYD to allocated');
        require(checkList[addr] == false, 'Airdrop::checkList: address already added');

        withdrawAmount[addr] = lydOut;
        checkList[addr] = true;

        totalAllocated = totalAllocated + lydOut;
        require(totalAllocated <= TOTAL_AIRDROP_SUPPLY, 'Airdrop::whitelistAddress: Exceeds LYD allocation');
    }

    /**
     * Whitelist multiple addresses in one call. Wrapper around whitelistAddress.
     * All parameters are arrays. Each array must be the same length. Each index
     * corresponds to one (address, lyd) tuple. Only callable by the owner.
     */
    function whitelistAddresses(address[] memory addrs, uint96[] memory lydOuts) external {
        require(msg.sender == owner, 'Airdrop::whitelistAddresses: unauthorized');
        require(addrs.length == lydOuts.length,
            'Airdrop::whitelistAddresses: incorrect array length');
        for (uint i = 0; i < addrs.length; i++) {
            whitelistAddress(addrs[i], lydOuts[i]);
        }
    }
}
