/** @type {import('next').NextConfig} */
const nextConfig = {
  // Emit a self-contained server bundle (.next/standalone + server.js) so the
  // Docker image can run `node server.js` without the full node_modules.
  // Harmless on Vercel, which ignores it.
  output: 'standalone',
  // The repo root is the workspace root; tell Next which dir to trace for the
  // standalone bundle so file tracing resolves correctly in the monorepo.
  outputFileTracingRoot: require('path').join(__dirname, '../../'),
};

module.exports = nextConfig;
