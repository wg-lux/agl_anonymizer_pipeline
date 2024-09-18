import os

def create_temp_directory():
    """
    Creates 'temp' and 'csv' directories within the base directory if they do not exist.
    
    Returns:
        tuple: Paths to temp_dir, base_dir, and csv_dir.
    """
    try:
        # Define the base directory (current directory of the script)
        base_dir = os.path.dirname(os.path.abspath(__file__))

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
    Creates 'temp' and 'csv' directories within the base directory if they do not exist.
    
    Returns:
        tuple: Paths to temp_dir, base_dir, and csv_dir.
    """
    try:
        # Define the base directory (current directory of the script)
        base_dir = os.path.dirname(os.path.abspath(__file__))

        # Define the paths to the temp and csv directories
        blur = os.path.join(base_dir, 'blurred_images')

        # Create temp_dir if it doesn't exist
        if not os.path.exists(blur):
            os.makedirs(blur)
            print(f"Created temp directory at {blur}")
        else:
            print(f"Blur directory already exists at {blur}")

        return blur

    except Exception as e:
        print(f"Error creating directories: {e}")
        raise  # Re-raise the exception after logging


