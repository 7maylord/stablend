'use client';

import { ToastContainer as ReactToastContainer, toast } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';

// Custom toast styles that match Stablend design
const toastStyles = {
  success: {
    style: {
      background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
      color: 'white',
      borderRadius: '12px',
      boxShadow: '0 10px 25px -5px rgba(16, 185, 129, 0.3)',
      border: 'none',
      fontSize: '14px',
      fontWeight: '500',
    },
    icon: '🎉',
  },
  error: {
    style: {
      background: 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
      color: 'white',
      borderRadius: '12px',
      boxShadow: '0 10px 25px -5px rgba(239, 68, 68, 0.3)',
      border: 'none',
      fontSize: '14px',
      fontWeight: '500',
    },
    icon: '❌',
  },
  info: {
    style: {
      background: 'linear-gradient(135deg, #3b82f6 0%, #2563eb 100%)',
      color: 'white',
      borderRadius: '12px',
      boxShadow: '0 10px 25px -5px rgba(59, 130, 246, 0.3)',
      border: 'none',
      fontSize: '14px',
      fontWeight: '500',
    },
    icon: 'ℹ️',
  },
  warning: {
    style: {
      background: 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)',
      color: 'white',
      borderRadius: '12px',
      boxShadow: '0 10px 25px -5px rgba(245, 158, 11, 0.3)',
      border: 'none',
      fontSize: '14px',
      fontWeight: '500',
    },
    icon: '⚠️',
  },
};

// Custom toast functions
export const showSuccessToast = (message: string) => {
  toast.success(message, {
    ...toastStyles.success,
    position: 'top-right',
    autoClose: 5000,
    hideProgressBar: false,
    closeOnClick: true,
    pauseOnHover: true,
    draggable: true,
  });
};

export const showErrorToast = (message: string) => {
  toast.error(message, {
    ...toastStyles.error,
    position: 'top-right',
    autoClose: 7000,
    hideProgressBar: false,
    closeOnClick: true,
    pauseOnHover: true,
    draggable: true,
  });
};

export const showInfoToast = (message: string) => {
  toast.info(message, {
    ...toastStyles.info,
    position: 'top-right',
    autoClose: 4000,
    hideProgressBar: false,
    closeOnClick: true,
    pauseOnHover: true,
    draggable: true,
  });
};

export const showWarningToast = (message: string) => {
  toast.warning(message, {
    ...toastStyles.warning,
    position: 'top-right',
    autoClose: 6000,
    hideProgressBar: false,
    closeOnClick: true,
    pauseOnHover: true,
    draggable: true,
  });
};

// Custom toast container component
export function ToastContainer() {
  return (
    <ReactToastContainer
      position="top-right"
      autoClose={5000}
      hideProgressBar={false}
      newestOnTop={false}
      closeOnClick
      rtl={false}
      pauseOnFocusLoss
      draggable
      pauseOnHover
      theme="light"
      toastStyle={{
        fontFamily: 'inherit',
      }}
      progressStyle={{
        background: 'rgba(255, 255, 255, 0.3)',
      }}
    />
  );
} 