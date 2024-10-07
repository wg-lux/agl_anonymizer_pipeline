import os



def create_blur_directory(directory="/tmp/agl_anonymizer"):
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
