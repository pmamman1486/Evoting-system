import { describe, it, beforeEach, expect } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@hirosystems/clarinet-sdk';
const simnet = await initSimnet();
const accounts = simnet.getAccounts();

const deployer = accounts.get('deployer')!;
const wallet1 = accounts.get('wallet_1')!;
const wallet2 = accounts.get('wallet_2')!;

describe('QuadraticVoting Contract', () => {
  beforeEach(() => {
    simnet.callPublicFn('VotingToken', 'mint', [Cl.principal(wallet1), Cl.uint(1000)], deployer);
    simnet.callPublicFn('VotingToken', 'mint', [Cl.principal(wallet2), Cl.uint(1000)], deployer);
    simnet.callPublicFn('VotingToken', 'stake', [Cl.uint(500)], wallet1);
    simnet.callPublicFn('VotingToken', 'stake', [Cl.uint(500)], wallet2);
  });

  it('creates quadratic proposal successfully', () => {
    const options = Cl.list([
      Cl.stringUtf8('Option A'),
      Cl.stringUtf8('Option B'),
      Cl.stringUtf8('Option C')
    ]);

    const result = simnet.callPublicFn(
      'QuadraticVoting',
      'create-quadratic-proposal',
      [
        Cl.stringUtf8('Test Proposal'),
        Cl.stringUtf8('Description of test proposal'),
        Cl.uint(100),
        options
      ],
      wallet1
    );

    expect(result.result).toBeOk(Cl.uint(1));
  });

  it('allocates voting credits correctly', () => {
    const options = Cl.list([Cl.stringUtf8('Yes'), Cl.stringUtf8('No')]);
    
    simnet.callPublicFn(
      'QuadraticVoting',
      'create-quadratic-proposal',
      [
        Cl.stringUtf8('Allocation Test'),
        Cl.stringUtf8('Test credit allocation'),
        Cl.uint(100),
        options
      ],
      wallet1
    );

    const result = simnet.callPublicFn(
      'QuadraticVoting',
      'allocate-voting-credits',
      [Cl.uint(1), Cl.uint(100)],
      wallet1
    );

    expect(result.result).toBeOk(Cl.uint(100));
  });




  it('prevents voting with insufficient credits', () => {
    const options = Cl.list([Cl.stringUtf8('Yes'), Cl.stringUtf8('No')]);
    
    simnet.callPublicFn(
      'QuadraticVoting',
      'create-quadratic-proposal',
      [
        Cl.stringUtf8('Insufficient Credits Test'),
        Cl.stringUtf8('Testing insufficient credits'),
        Cl.uint(100),
        options
      ],
      wallet1
    );

    simnet.callPublicFn(
      'QuadraticVoting',
      'allocate-voting-credits',
      [Cl.uint(1), Cl.uint(10)],
      wallet2
    );

    const result = simnet.callPublicFn(
      'QuadraticVoting',
      'cast-quadratic-vote',
      [Cl.uint(1), Cl.uint(0), Cl.uint(5)],
      wallet2
    );

    expect(result.result).toBeErr(Cl.uint(201));
  });

  it('finalizes proposal correctly', () => {
    const options = Cl.list([Cl.stringUtf8('Final'), Cl.stringUtf8('Test')]);
    
    simnet.callPublicFn(
      'QuadraticVoting',
      'create-quadratic-proposal',
      [
        Cl.stringUtf8('Finalization Test'),
        Cl.stringUtf8('Testing proposal finalization'),
        Cl.uint(5),
        options
      ],
      wallet1
    );

    simnet.mineEmptyBlocks(10);

    const result = simnet.callPublicFn(
      'QuadraticVoting',
      'finalize-quadratic-proposal',
      [Cl.uint(1)],
      wallet1
    );

    expect(result.result).toBeOk(Cl.bool(true));
  });
});
