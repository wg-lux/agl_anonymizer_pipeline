import os

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

- directory
- temp_directory
'''

# Default directory paths for main and temp directories
# Update these paths only if necessary
directory = "/var/anonymizer"
temp_directory = "var/tmp/agl_anonymizer"


def create_directories(directories):
    """
    Creates a list of directories if they do not exist.
    
    Args:
        directories (list): A list of directory paths to create.
    """
    for dir_path in directories:
        if not os.path.exists(dir_path):
            os.makedirs(dir_path)
            print(f"Created directory: {dir_path}")
        else:
            print(f"Directory already exists: {dir_path}")


def create_main_directory(directory="/var/agl_anonymizer"):
    """
    Creates the main directory in a writable location (outside the Nix store).
    
    Args:
        directory (str): The path where the main directory will be created.
    
    Returns:
        str: The path to the main directory.
    """
    try:
        main_directory = os.path.join(directory, 'main')
        create_directories([main_directory])
        return main_directory

    except Exception as e:
        print(f"Error creating main directory at {directory}: {e}")
        raise


def create_temp_directory(temp_directory="var/temp/agl_anonymizer", directory=None):
    """
    Creates 'temp' and 'csv' directories in the given temp and main directories.
    
    Args:
        temp_directory (str): The path where the temp directory will be created.
        directory (str): The main directory path, where the csv directory will be created.
                         If not provided, it will use the result of create_main_directory.
    
    Returns:
        tuple: Paths to temp_dir, base_dir, and csv_dir.
    """
    try:
        if directory is None:
            directory = create_main_directory()

        temp_dir = os.path.join(temp_directory, 'temp')
        csv_dir = os.path.join(directory, 'csv_training_data')

        create_directories([temp_dir, csv_dir])

        return temp_dir, directory, csv_dir

    except Exception as e:
        print(f"Error setting temp or base directory: {e}")
        raise


def create_blur_directory(directory="/var/agl_anonymizer"):
    """
    Creates 'blurred_images' directory in a writable location (outside the Nix store).
    
    Args:
        directory (str): The path where the blurred images directory will be created.
    
    Returns:
        str: Path to the blurred images directory.
    """
    try:
        # Ensure the main directory exists
        main_directory = create_main_directory(directory)
        blur_dir = os.path.join(main_directory, 'blurred_results')

        create_directories([blur_dir])

        return blur_dir

    except Exception as e:
        print(f"Error creating blur directory at {blur_dir}: {e}")
        raise
