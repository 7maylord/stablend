import { cookieStorage, createStorage, http } from '@wagmi/core'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { mantle, mantleTestnet, mantleSepoliaTestnet } from '@reown/appkit/networks'

export const projectId = process.env.NEXT_PUBLIC_PROJECT_ID

if (!projectId) {
  throw new Error('Project ID is not defined')
}

// Custom Mantle Sepolia configuration
const customMantleSepolia = {
  ...mantleSepoliaTestnet,
  rpcUrls: {
    default: { 
      http: [process.env.NEXT_PUBLIC_MANTLE_SEPOLIA_RPC || 'https://mantle-sepolia.g.alchemy.com/v2/hOFsEmyHlw0Ez4aLryoLetL-YwfWJC2D'] 
    },
    public: { 
      http: [process.env.NEXT_PUBLIC_MANTLE_SEPOLIA_RPC || 'https://mantle-sepolia.g.alchemy.com/v2/hOFsEmyHlw0Ez4aLryoLetL-YwfWJC2D'] 
    },
  },
}

export const networks = [mantle, mantleTestnet, customMantleSepolia]

//Set up the Wagmi Adapter (Config)
export const wagmiAdapter = new WagmiAdapter({
  storage: createStorage({
    storage: cookieStorage
  }),
  ssr: true,
  projectId,
  networks
})

export const config = wagmiAdapter.wagmiConfig