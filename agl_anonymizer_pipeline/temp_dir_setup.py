import os

# Function to create temp directory if it doesn't exist
def create_temp_directory():
    # Define the base directory (current directory of the script)
    base_dir = os.path.dirname(os.path.abspath(__file__))

    # Define the path to the temp directory
    temp_dir = os.path.join(base_dir, 'temp')
    if not os.path.exists(temp_dir):
        try:
            os.makedirs(temp_dir)
            print(f"Created temp directory at {temp_dir}")
        except Exception as e:
            print(f"Error creating temp directory: {e}")
    else:
        pass        
    return temp_dir, base_dir

