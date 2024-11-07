use pyo3::prelude::*;

/// Example function exposed to Python
#[pyfunction]
fn greet(name: &str) -> PyResult<String> {
    Ok(format!("Hello, {}!", name))
}

/// Define the Python module
#[pymodule]
fn my_rust_library(py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(greet, m)?)?;
    Ok(())
}
