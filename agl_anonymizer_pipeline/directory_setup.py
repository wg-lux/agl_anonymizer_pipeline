import os
import tempfile

'''
Main Directory Setup

The functions in this script define where the storage for anonymized data
and intermediate results will occur.

Functions:

- create_main_directory:
  - The main directory stores the final anonymized results as well as structured study and training data ready for export.
  
- create_temp_directory:
  - The temp directory stores intermediate results during the anonymization process. It is cleaned up regularly.
  
- create_blur_directory:
  - The blur directory stores blurred images. This directory is also cleaned up regularly.

To change the default installation paths, update these variables:

- main_directory
- temp_directory
'''

from pathlib import Path

# Default directory paths for main and temp directories
# The base directory can be overridden via environment variables
# default_main_directory = os.environ.get("AGL_ANONYMIZER_DEFAULT_MAIN_DIR","/etc/agl-anonymizer")
# default_temp_directory = os.environ.get("AGL_ANONYMIZER_DEFAULT_TEMP_DIR", "/etc/agl-anonymizer-temp")

MAIN_DIR = Path("/etc/agl-anonymizer")
TEMP_DIR_ROOT = Path("/etc/agl-anonymizer-temp")

from typing import List

def _str_to_path(path:str):
    if isinstance(path, str):
        path = Path(path)
        
    return path

def create_directories(directories:List[Path]=None)->List[Path]:
    """
    Helper function.
    Creates a list of directories if they do not exist.
    
    Args:
        directories (list): A list of directory paths to create.
    """

    if not directories:
        directories = [
            MAIN_DIR,
            TEMP_DIR_ROOT
        ]
        
    else: 
        directories = [_str_to_path(directory) for directory in directories]

    for dir_path in directories:
        if dir_path.exists():
            dir_path.mkdir(parents = True, exist_ok=True)
            
            print(f"Created directory: {dir_path}")
        else:
            print(f"Directory already exists: {dir_path}")
            
    return directories
            
def create_main_directory(default_main_directory:Path = None):
    """
    Creates the main directory in a writable location (outside the Nix store).
    
    Args:
        directory (str): The path where the main directory will be created.
                         Defaults to `default_main_directory`.
    
    Returns:
        str: The path to the main directory.
    """
    # check if string path, make to path object if necessary
    
    
    if not default_main_directory:
        default_main_directory = MAIN_DIR
    else:
        default_main_directory = _str_to_path(default_main_directory)
    
    if default_main_directory.exists():
        print(f"Using default main directory: {default_main_directory.as_posix()}")

    else:
        print(f"Creating main directory, directory at {default_main_directory} not found")
        create_directories([default_main_directory])
        print(f"Main directory created at {default_main_directory}")

    return default_main_directory

def create_temp_directory(default_temp_directory:Path=None, default_main_directory:Path=None):
    """
    Creates 'temp' and 'csv' directories in the given temp and main directories.
    
    Args:
        temp_directory (str): The path where the temp directory will be created.
                              Defaults to `default_temp_directory`.
        main_directory (str): The main directory path, where the csv directory will be created.
                              If not provided, it will use the result of create_main_directory.
    
    Returns:
        tuple: Paths to temp_dir, base_dir, and csv_dir.
    """
    
    if not default_temp_directory:
        default_temp_directory = TEMP_DIR_ROOT
    else:
        default_temp_directory = _str_to_path(default_temp_directory)
    
    if not default_main_directory:
        default_main_directory = MAIN_DIR
    else:
        default_main_directory = _str_to_path(default_main_directory)    
    
    
    temp_dir = default_temp_directory.joinpath('temp')
    csv_dir = default_main_directory.joinpath('csv_training_data')
    # print("Using default temp and main directory settings")   
    
    if temp_dir.exists() and csv_dir.exists():
        return temp_dir, default_main_directory, csv_dir 
    
    else:
        print(f"Creating temp and csv directories, directories at {temp_dir} and {csv_dir} not found")
        create_directories([temp_dir, csv_dir])
        print(f"Temp and csv directories created at {temp_dir} and {csv_dir}")
        return temp_dir, default_main_directory, csv_dir




def create_blur_directory(default_main_directory:Path=None) -> Path:
    """
    Creates 'blurred_images' directory in a writable location (outside the Nix store).
    
    Args:
        directory (str): The path where the blurred images directory will be created.
                         Defaults to `default_main_directory`.
    
    Returns:
        str: Path to the blurred images directory.
    """
    
    if not default_main_directory:
        default_main_directory = MAIN_DIR
    else:
        default_main_directory = _str_to_path(default_main_directory)
    
    
    blur_dir = default_main_directory.joinpath('blurred_results')
    if blur_dir.exists():
        print("Using default blur directory settings")
  
    else:
        print(f"Creating blur directory, directory at {blur_dir} not found")
        blur_dir = os.path.join(default_main_directory, '/blurred_results')

        create_directories([blur_dir])
        print(f"Blur directory created at {blur_dir}")

        return blur_dir

        
        
