fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rustc-link-search=native={}/lib", 
             std::env::var("LLVM_SYS_120_PREFIX").unwrap());
    println!("cargo:rustc-link-lib=LLVM-12");
}