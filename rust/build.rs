use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    
    // Get LLVM paths from environment
    let llvm_prefix = env::var("LLVM_SYS_120_PREFIX")
        .expect("LLVM_SYS_120_PREFIX must be set");
    let libclang_path = env::var("LIBCLANG_PATH")
        .expect("LIBCLANG_PATH must be set");

    // Add LLVM lib directory to library search path
    println!("cargo:rustc-link-search=native={}/lib", llvm_prefix);
    
    // Add libclang path
    println!("cargo:rustc-link-search=native={}", libclang_path);
    
    // Link LLVM libraries
    println!("cargo:rustc-link-lib=LLVM-12");
    println!("cargo:rustc-link-lib=clang");
    
    // Set include path for bindgen
    let clang_path = PathBuf::from(&libclang_path);
    println!("cargo:include={}", clang_path.parent().unwrap().display());
}