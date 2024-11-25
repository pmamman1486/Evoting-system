import React, { useState } from 'react';
import { useAuth } from '@micro-stacks/react';
import { useAccount, useOpenContractCall } from '@micro-stacks/react';
import { uintCV, serializeCV, stringUtf8CV } from '@stacks/transactions';
import { Link } from 'react-router-dom';
import { WalletConnectButton } from '../components/wallet-connect-button';
const CreateProposalPage = () => {
  // Form State
  const [description, setDescription] = useState('');
  const [deadline, setDeadline] = useState('');
  const [rewardAmount, setRewardAmount] = useState('');
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);

  // Simulated Constants (these should ideally come from a smart contract query)
  const MIN_PROPOSAL_DURATION = 1440; // 1 day in blocks
  const MIN_REWARD_AMOUNT = 100; // Minimum reward amount

  // Auth and contract hooks
  const { isSignedIn, signIn, signOut } = useAuth();
  const { stxAddress } = useAccount();
  const { openContractCall } = useOpenContractCall();

  // Form Submission Handler
  const handleSubmit = async e => {
    e.preventDefault();

    // Validation
    if (!description || description.length > 500) {
      setError('Description is required and must not exceed 500 characters.');
      return;
    }
    if (!deadline || Number(deadline) <= MIN_PROPOSAL_DURATION) {
      setError(
        `Deadline must be greater than the minimum proposal duration (${MIN_PROPOSAL_DURATION} blocks).`
      );
      return;
    }
    if (!rewardAmount || Number(rewardAmount) < MIN_REWARD_AMOUNT) {
      setError(`Reward amount must be at least ${MIN_REWARD_AMOUNT}.`);
      return;
    }

    if (!isSignedIn) {
      setMessage('❌ Please connect your wallet before creating a proposal.');
      return;
    }

    setLoading(true);
    setMessage('');
    setError('');

    try {
      const uintDeadline = parseInt(deadline);
      const uintRewardAmount = parseInt(rewardAmount);

      // Prepare function arguments for contract call
      const functionArgs = [
        uintCV(uintRewardAmount),
        uintCV(uintDeadline),
        stringUtf8CV(description),
      ];
      const serializedArgs = functionArgs.map(arg => serializeCV(arg));

      const contractCallOptions = {
        contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM', // Replace with your contract address
        contractName: 'voting-contract', // Replace with your contract name
        functionName: 'create-proposal',
        functionArgs: serializedArgs,
        onFinish: data => {
          setMessage(`🎉 Proposal created successfully!`);
          console.log('Transaction data:', data);
        },
        onCancel: () => {
          setMessage('❌ Transaction canceled.');
        },
      };

      // Trigger the contract call
      await openContractCall(contractCallOptions);
    } catch (error) {
      console.error('Error creating proposal:', error);
      setMessage('❌ Proposal creation failed: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-gradient-to-r from-blue-50 via-white to-blue-50 p-4 sm:p-8 max-w-xl mx-auto bg-white bg-opacity-10 rounded-lg shadow-lg backdrop-blur-md">
      <h2 className=" text-blue-600 mb-6 text-center text-5xl font-extrabold">Create Proposal</h2>

      {!isSignedIn ? (
        <WalletConnectButton />
      ) : (
        <>
          <p className="text-gray-400 text-sm text-center mb-4">
            Connected as: <strong>{stxAddress}</strong>
          </p>

          <form
            onSubmit={handleSubmit}
            className="space-y-6"
          >
            {/* Proposal Description */}
            <div>
              <label
                htmlFor="description"
                className="block text-sm font-medium text-gray-700"
              >
                Proposal Description
              </label>
              <textarea
                id="description"
                className="mt-1 block w-full p-3 border border-gray-300 rounded-lg shadow-sm focus:ring-blue-500 focus:border-blue-500"
                placeholder="Describe your proposal (Max 500 characters)"
                value={description}
                onChange={e => setDescription(e.target.value)}
                maxLength={500}
                rows={4}
                required
              ></textarea>
            </div>

            {/* Proposal Deadline */}
            <div>
              <label
                htmlFor="deadline"
                className="block text-sm font-medium text-gray-700"
              >
                Proposal Deadline (in blocks)
              </label>
              <input
                type="number"
                id="deadline"
                className="mt-1 block w-full p-3 border border-gray-300 rounded-lg shadow-sm focus:ring-blue-500 focus:border-blue-500"
                placeholder={`Minimum: ${MIN_PROPOSAL_DURATION + 1} blocks`}
                value={deadline}
                onChange={e => setDeadline(e.target.value)}
                required
              />
            </div>

            {/* Reward Amount */}
            <div>
              <label
                htmlFor="rewardAmount"
                className="block text-sm font-medium text-gray-700"
              >
                Reward Amount
              </label>
              <input
                type="number"
                id="rewardAmount"
                className="mt-1 block w-full p-3 border border-gray-300 rounded-lg shadow-sm focus:ring-blue-500 focus:border-blue-500"
                placeholder={`Minimum: ${MIN_REWARD_AMOUNT}`}
                value={rewardAmount}
                onChange={e => setRewardAmount(e.target.value)}
                required
              />
            </div>

            {/* error message */}
            {message && (
              <p
                className={`mt-4 text-center font-medium text-lg ${
                  message.includes('successful') ? 'text-green-500 animate-pulse' : 'text-red-500'
                }`}
              >
                {message}
              </p>
            )}

            {/* Submit Button */}
            <div>
              <button
                type="submit"
                className={`w-full ${
                  loading ? 'bg-gray-400 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-800'
                } text-white py-3 rounded-lg font-bold shadow-md transition-transform transform ${
                  loading ? '' : 'hover:scale-105'
                }`}
                disabled={loading}
              >
                {loading ? 'Processing...' : 'Create Proposal'}
              </button>
            </div>
          </form>

          <button
            onClick={signOut}
            className="w-full mt-4 bg-red-500 text-black py-3 rounded-lg font-bold shadow-md hover:bg-red-300 transition-transform transform hover:scale-105"
          >
            Sign out
          </button>
        </>
      )}

      <Link to="/">
        <button className="w-full mt-4 bg-gray-600 text-white py-3 rounded-lg font-bold shadow-md hover:bg-gray-800 transition-transform transform hover:scale-105">
          Home
        </button>
      </Link>
    </div>
  );
};

export default CreateProposalPage;
