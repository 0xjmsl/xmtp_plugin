import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  build: {
    outDir: 'dist',
    target: 'esnext',
    minify: true,
    sourcemap: true,
    rollupOptions: {
      input: 'xmtp_client_manager.js',
      output: {
        entryFileNames: 'xmtp_bundle.js',
        format: 'es',
      },
    },
  },
  worker: {
    format: 'es',
  },
});
