import { describe, it, beforeEach, expect } from 'vitest';

// Mocking the environment and contract
let contract: any; // Your contract initialization here

describe('VotingToken Contract', () => {
    let tokenOwner: string; // Variable to hold the token owner address

    beforeEach(async () => {
        tokenOwner = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG'; // Replace with the initial token owner's address
        contract = await deployVotingTokenContract(tokenOwner); // Your contract deployment function
    });

    it('should return the correct token name', async () => {
        const response = await contract.get_name();
        expect(response).toEqual("VotingToken");
    });

    it('should return the correct token symbol', async () => {
        const response = await contract.get_symbol();
        expect(response).toEqual("VT");
    });

    it('should return the correct decimals', async () => {
        const response = await contract.get_decimals();
        expect(response).toEqual(6);
    });

    it('should return the total supply as zero initially', async () => {
        const response = await contract.get_total_supply();
        expect(response).toEqual(0);
    });

    it('should allow minting tokens to the recipient', async () => {
        const recipient = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG'; // Replace with actual address
        const amount = 100;
        await contract.mint(recipient, amount);
        
        const balance = await contract.get_balance(recipient);
        expect(balance).toEqual(amount);
        
        const totalSupply = await contract.get_total_supply();
        expect(totalSupply).toEqual(amount);
    });

    it('should not allow unauthorized minting', async () => {
        const unauthorizedAddress = 'unauthorized_address'; // Replace with a different address
        const amount = 100;
        await expect(contract.mint(unauthorizedAddress, amount)).rejects.toThrow('Unauthorized');
    });

    it('should allow burning tokens', async () => {
        const amount = 50;
        await contract.mint(tokenOwner, 100); // Ensure there are tokens to burn
        await contract.burn(amount);
        
        const balance = await contract.get_balance(tokenOwner);
        expect(balance).toEqual(50);
        
        const totalSupply = await contract.get_total_supply();
        expect(totalSupply).toEqual(50);
    });

    it('should not allow burning more tokens than owned', async () => {
        await expect(contract.burn(100)).rejects.toThrow('Insufficient balance');
    });

    it('should allow staking tokens', async () => {
        const amount = 100;
        await contract.mint(tokenOwner, amount);
        await contract.stake(amount);
        
        const stakedBalance = await contract.get_staked_balance(tokenOwner);
        expect(stakedBalance).toEqual(amount);
        
        const balance = await contract.get_balance(tokenOwner);
        expect(balance).toEqual(0);
    });

    it('should not allow staking more tokens than owned', async () => {
        await expect(contract.stake(100)).rejects.toThrow('Insufficient balance');
    });

    it('should allow unstaking tokens', async () => {
        const amount = 100;
        await contract.mint(tokenOwner, 100);
        await contract.stake(amount);
        await contract.unstake(amount);
        
        const stakedBalance = await contract.get_staked_balance(tokenOwner);
        expect(stakedBalance).toEqual(0);
        
        const balance = await contract.get_balance(tokenOwner);
        expect(balance).toEqual(100);
    });

    it('should not allow unstaking more tokens than staked', async () => {
        await expect(contract.unstake(100)).rejects.toThrow('Insufficient stake');
    });

    it('should allow changing token owner', async () => {
        const newOwner = 'new_owner_address'; // Replace with actual address
        await contract.change_owner(newOwner);
        
        const tokenOwnerAddress = await contract.get_token_owner();
        expect(tokenOwnerAddress).toEqual(newOwner);
    });

    it('should return the correct token URI', async () => {
        const response = await contract.get_token_uri();
        expect(response).toEqual(null); // Assuming initial state is none
    });
});

async function deployVotingTokenContract(initialOwner: string) {
    // State variables
    const balances: Record<string, number> = {};
    const stakedBalances: Record<string, number> = {};
    let totalSupply = 0; // Initial supply of tokens
    let tokenOwner = initialOwner; // Setting the token owner

    const contract = {
        // Mock contract methods
        get_name: async () => "VotingToken",
        get_symbol: async () => "VT",
        get_decimals: async () => 6,
        get_total_supply: async () => totalSupply,
        get_balance: async (account: string) => balances[account] || 0,
        get_staked_balance: async (account: string) => stakedBalances[account] || 0,
        mint: async (recipient: string, amount: number) => {
            if (recipient !== tokenOwner) {
                throw new Error("Unauthorized");
            }
            if (amount <= 0) {
                throw new Error("Invalid amount");
            }
            // Mint tokens
            balances[recipient] = (balances[recipient] || 0) + amount;
            totalSupply += amount;
            return amount;
        },
        burn: async (amount: number) => {
            const currentBalance = balances[tokenOwner] || 0;
            if (currentBalance < amount) {
                throw new Error("Insufficient balance");
            }
            // Burn tokens
            balances[tokenOwner] -= amount;
            totalSupply -= amount;
            return amount;
        },
        stake: async (amount: number) => {
            const currentBalance = balances[tokenOwner] || 0;
            if (currentBalance < amount) {
                throw new Error("Insufficient balance");
            }
            // Stake tokens
            balances[tokenOwner] -= amount;
            stakedBalances[tokenOwner] = (stakedBalances[tokenOwner] || 0) + amount;
            return amount;
        },
        unstake: async (amount: number) => {
            const stakedBalance = stakedBalances[tokenOwner] || 0;
            if (stakedBalance < amount) {
                throw new Error("Insufficient staked balance");
            }
            // Unstake tokens
            stakedBalances[tokenOwner] -= amount;
            balances[tokenOwner] = (balances[tokenOwner] || 0) + amount;
            return amount;
        },
        change_owner: async (newOwner: string) => {
            if (tokenOwner !== tokenOwner) {
                throw new Error("Unauthorized");
            }
            // Change token owner
            tokenOwner = newOwner;
            return true;
        },
        get_token_owner: async () => {
            return tokenOwner;
        },
        get_token_uri: async () => null,
    };

    return contract;
}
