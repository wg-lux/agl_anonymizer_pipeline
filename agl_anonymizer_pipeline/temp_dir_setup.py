import os

def create_temp_directory():
    """
    Creates 'temp' and 'csv' directories in a writable location (outside the Nix store).
    
    Returns:
        tuple: Paths to temp_dir, base_dir, and csv_dir.
    """
    try:
        # Use a writable directory (e.g., /tmp or a user-provided path via an environment variable)
        base_dir = os.getenv('AGL_ANONYMIZER_DATA_DIR', '/tmp/agl_anonymizer')

        # Define the paths to the temp and csv directories
        temp_dir = os.path.join(base_dir, 'temp')
        csv_dir = os.path.join(base_dir, 'csv_files')

        # Create temp_dir if it doesn't exist
        if not os.path.exists(temp_dir):
            os.makedirs(temp_dir)
            print(f"Created temp directory at {temp_dir}")
        else:
            print(f"Temp directory already exists at {temp_dir}")

        # Create csv_dir if it doesn't exist
        if not os.path.exists(csv_dir):
            os.makedirs(csv_dir)
            print(f"Created csv directory at {csv_dir}")
        else:
            print(f"CSV directory already exists at {csv_dir}")

        return temp_dir, base_dir, csv_dir

    except Exception as e:
        print(f"Error creating directories: {e}")
        raise  # Re-raise the exception after logging

def create_blur_directory():
    """
    Creates 'blurred_images' directory in a writable location (outside the Nix store).
    
    Returns:
        string: Path to the blurred images directory.
    """
    try:
        # Use a writable directory (e.g., /tmp or a user-provided path via an environment variable)
        base_dir = os.getenv('AGL_ANONYMIZER_DATA_DIR', '/tmp/agl_anonymizer')

        # Define the path to the blurred images directory
        blur_dir = os.path.join(base_dir, 'blurred_images')

        # Create blur_dir if it doesn't exist
        if not os.path.exists(blur_dir):
            os.makedirs(blur_dir)
            print(f"Created blur directory at {blur_dir}")
        else:
            print(f"Blur directory already exists at {blur_dir}")

        return blur_dir

    except Exception as e:
        print(f"Error creating directories: {e}")
        raise  # Re-raise the exception after logging
