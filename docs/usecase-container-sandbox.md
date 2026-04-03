# Use Case 2: Container-Native Sandboxes — Any Language, Any Framework, Instant

## Overview

Moat sandboxes now support OCI container images as their root filesystem. Instead of relying on a generic Linux base, agents can request sandboxes pre-loaded with any container image — Python 3.12, Node 22, Rust 1.86, Go 1.24, or even custom images with your entire toolchain pre-installed.

## Architecture

```
  Agent: create_sandbox(image: "python:3.12-slim")
         │
         ▼
  Moat Pool Manager
         │
    ┌────┴────┐
    │ skopeo  │──pull──▶ Container Registry (ghcr.io / docker.io)
    │ flatten │──cache──▶ OCI Dir Cache (content-addressed by digest)
    └────┬────┘
         │
    ┌────┴────────────┐
    │  Bubblewrap:    │     Firecracker:
    │  overlayfs      │     erofs → virtio-blk
    │  lower=image    │     read-only VM drive
    │  upper=sandbox  │
    └─────────────────┘
```

## How It Works

1. **Image Pull** — When a sandbox specifies an `image`, moat uses skopeo to pull the OCI image from any registry. Layers are flattened with full OCI whiteout handling into a single directory.

2. **Content-Addressed Cache** — Images are cached by digest. If two agents request `python:3.12-slim`, the second one is instant — no re-pull, no re-flatten.

3. **Backend-Specific Mounting**:
   - **Bubblewrap**: Image directory becomes the overlayfs lower layer. Each sandbox gets its own CoW upper layer — writes are isolated, the base image is shared read-only.
   - **Firecracker**: Flattened image is converted to erofs (compressed read-only filesystem) and attached as a virtio-blk drive to the microVM.

4. **Full Tool Access** — The sandbox runs with the image's full toolchain. A `node:22` sandbox has npm, npx, yarn. A `rust:1.86` sandbox has cargo, rustc, clippy.

## Demo Scenario

```
User: "Build and test a Rust WebAssembly module"

Agent (moat-sandbox-coder):
  1. create_sandbox(image: "rust:1.86-slim")
  2. shell("rustup target add wasm32-unknown-unknown")
  3. write_file("src/lib.rs", wasm_code)
  4. shell("cargo build --target wasm32-unknown-unknown --release")
  5. shell("wasm-opt -Oz target/wasm32-unknown-unknown/release/lib.wasm -o optimized.wasm")
  6. read_file("optimized.wasm") → returns the compiled WASM binary
  7. take_snapshot("rust-wasm-working") → save state for later
```

## Why This Matters

- **Language-agnostic** — Any container image works: Python, Node, Rust, Go, Java, .NET, Ruby
- **Reproducible** — Pinned digests guarantee identical environments
- **Fast** — Content-addressed caching means the second request for the same image is instant
- **Secure** — Image layers are read-only; sandbox writes are isolated via CoW
- **No custom images needed** — Use standard Docker Hub / GHCR images directly
