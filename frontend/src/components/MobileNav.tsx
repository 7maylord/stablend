'use client'

import { useState } from 'react'
import Link from 'next/link'

export function MobileNav() {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <>
      {/* Mobile menu button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="lg:hidden p-2 rounded-md text-gray-700 hover:text-blue-600 hover:bg-gray-100 transition-colors focus-ring"
      >
        <svg
          className="w-6 h-6"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          {isOpen ? (
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M6 18L18 6M6 6l12 12"
            />
          ) : (
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 6h16M4 12h16M4 18h16"
            />
          )}
        </svg>
      </button>

      {/* Mobile menu overlay */}
      {isOpen && (
        <div className="lg:hidden">
          <div
            className="mobile-menu-overlay"
            onClick={() => setIsOpen(false)}
          />
          <div className="mobile-menu">
            <div className="flex flex-col h-full">
              {/* Close button */}
              <div className="flex justify-end p-4">
                <button
                  onClick={() => setIsOpen(false)}
                  className="p-2 rounded-md text-gray-700 hover:text-blue-600 hover:bg-gray-100 transition-colors focus-ring"
                >
                  <svg
                    className="w-6 h-6"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>

              {/* Navigation links */}
              <nav className="flex-1 px-4 space-y-4">
                <Link
                  href="/"
                  onClick={() => setIsOpen(false)}
                  className="block py-3 text-gray-700 hover:text-blue-600 transition-colors border-b border-gray-100"
                >
                  Home
                </Link>
                <a
                  href="#features"
                  onClick={() => setIsOpen(false)}
                  className="block py-3 text-gray-700 hover:text-blue-600 transition-colors border-b border-gray-100"
                >
                  Features
                </a>
                <a
                  href="#how-it-works"
                  onClick={() => setIsOpen(false)}
                  className="block py-3 text-gray-700 hover:text-blue-600 transition-colors border-b border-gray-100"
                >
                  How it Works
                </a>
                <a
                  href="#about"
                  onClick={() => setIsOpen(false)}
                  className="block py-3 text-gray-700 hover:text-blue-600 transition-colors border-b border-gray-100"
                >
                  About
                </a>
              </nav>

              {/* App button */}
              <div className="p-4 border-t border-gray-200">
                <Link
                  href="/dashboard"
                  onClick={() => setIsOpen(false)}
                  className="block w-full btn-gradient text-center"
                >
                  Launch App
                </Link>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  )
} 