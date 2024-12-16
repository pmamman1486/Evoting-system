import { useAuth } from '@micro-stacks/react';

export const WalletConnectButton = () => {
  const { openAuthRequest, isRequestPending, signOut, isSignedIn } = useAuth();
  const label = isRequestPending ? 'Loading...' : isSignedIn ? 'Sign out' : 'Connect Wallet';
  return (
    <button
      className="w-full bg-blue-500 text-black py-3 rounded-lg font-bold shadow-md hover:bg-blue-300 transition-transform transform hover:scale-105"
      onClick={() => {
        if (isSignedIn) void signOut();
        else void openAuthRequest();
      }}
    >
      {label}
    </button>
  );
};
