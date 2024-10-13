#!/bin/bash

set -e

# Function to create a crate only if it doesn't exist
create_crate_if_not_exists() {
    crate_name=$1
    if [ ! -d "$crate_name" ]; then
        cargo new $crate_name --lib
    else
        echo "$crate_name crate already exists. Skipping creation."
    fi
}

# Initialize the monorepo using Cargo (if not already done)
create_crate_if_not_exists "repliq-core"
create_crate_if_not_exists "repliq-ipc"
create_crate_if_not_exists "repliq-replication"
create_crate_if_not_exists "repliq-k8s"
create_crate_if_not_exists "repliq-client"

# Add dependencies between crates
# Add repliq-core as a dependency to repliq-ipc (idempotent check for dependency)
add_dependency_if_not_exists() {
    crate_path=$1
    dependency_name=$2
    dependency_path=$3

    if ! grep -q "$dependency_name" "$crate_path/Cargo.toml"; then
        echo "Adding $dependency_name as a dependency to $crate_path"
        echo -e "\n[dependencies]\n$dependency_name = { path = \"$dependency_path\" }" >> "$crate_path/Cargo.toml"
    else
        echo "$dependency_name already added as a dependency to $crate_path. Skipping."
    fi
}

add_dependency_if_not_exists "repliq-ipc" "repliq-core" "../repliq-core"
add_dependency_if_not_exists "repliq-replication" "repliq-core" "../repliq-core"
add_dependency_if_not_exists "repliq-replication" "repliq-ipc" "../repliq-ipc"
add_dependency_if_not_exists "repliq-k8s" "repliq-core" "../repliq-core"
add_dependency_if_not_exists "repliq-k8s" "repliq-ipc" "../repliq-ipc"
add_dependency_if_not_exists "repliq-k8s" "repliq-replication" "../repliq-replication"
add_dependency_if_not_exists "repliq-client" "repliq-core" "../repliq-core"
add_dependency_if_not_exists "repliq-client" "repliq-ipc" "../repliq-ipc"
add_dependency_if_not_exists "repliq-client" "repliq-replication" "../repliq-replication"
add_dependency_if_not_exists "repliq-client" "repliq-k8s" "../repliq-k8s"

# Create directories for tests and benchmarks (if not already done)
mkdir -p benches
mkdir -p tests/integration
mkdir -p tests/end_to_end

# Create example test files (if not already done)
touch tests/integration/ipc_test.rs
touch tests/end_to_end/replication_test.rs

# Create example benchmark files (if not already done)
touch benches/enqueue_benchmark.rs

# Add necessary configuration to Cargo.toml files
# (Example: Add benchmark and test dependencies to repliq-core/Cargo.toml)
if ! grep -q "\[\[bench\]\]" "repliq-core/Cargo.toml"; then
    cat << EOF >> repliq-core/Cargo.toml

[[bench]]
name = "enqueue_benchmark"
harness = false

[dev-dependencies]
criterion = "0.4" # Or your preferred benchmarking crate
EOF
else
    echo "Benchmark configuration already exists in repliq-core/Cargo.toml. Skipping."
fi

# Create a .gitignore file (if not already done)
if [ ! -f .gitignore ]; then
    cat << EOF >> .gitignore
/target
/benches/target
/tests/integration/target
/tests/end_to_end/target
EOF
else
    echo ".gitignore file already exists. Skipping creation."
fi

# Commit the changes
git add .
git commit -m "Initial project structure with client library" || echo "No changes to commit."

# Create a develop branch (if not already done)
if ! git rev-parse --verify develop >/dev/null 2>&1; then
    git checkout -b develop
else
    echo "Branch 'develop' already exists. Skipping."
fi

echo "k8s-repli-queue project initialized successfully!"
