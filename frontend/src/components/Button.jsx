import React from 'react';

const Button = ({ text, onClick, variant = 'primary' }) => {
  const baseStyle = 'px-6 py-3 w-40 rounded-lg text-white text-sm font-semibold';
  const variantStyle = variant === 'primary' ? 'bg-blue-600 hover:bg-blue-700' : 'bg-gray-600 hover:bg-gray-700';

  return (
    <button onClick={onClick} className={`${baseStyle} ${variantStyle}`}>
      {text}
    </button>
  );
};

export default Button;
