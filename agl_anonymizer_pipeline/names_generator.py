import os
import random
import gender_guesser.detector as gender
import os
from .names_adder import add_device_name_to_image, add_full_name_to_image
from .temp_dir_setup import create_temp_directory 


temp_dir, base_dir = create_temp_directory()

# Define file paths
female_names_file = os.path.join(base_dir, 'names_dict', 'first_and_last_names_female_ascii.txt')
male_names_file = os.path.join(base_dir, 'names_dict', 'first_and_last_names_male_ascii.txt')
female_first_names_file = os.path.join(base_dir, 'names_dict', 'first_names_female_ascii.txt')
female_last_names_file = os.path.join(base_dir, 'names_dict', 'last_names_female_ascii.txt')
neutral_first_names_file = os.path.join(base_dir, 'names_dict', 'first_names_neutral_ascii.txt')
neutral_last_names_file = os.path.join(base_dir, 'names_dict', 'last_names_neutral_ascii.txt')
male_first_names_file = os.path.join(base_dir, 'names_dict', 'first_names_male_ascii.txt')
male_last_names_file = os.path.join(base_dir, 'names_dict', 'last_names_male_ascii.txt')

# Load names from files
def load_names(file_path):
    with open(file_path, 'r') as file:
        return [line.strip() for line in file]

female_names = load_names(female_names_file)
male_names = load_names(male_names_file)
neutral_first_names = load_names(neutral_first_names_file)
neutral_last_names = load_names(neutral_last_names_file)
female_first_names = load_names(female_first_names_file)
female_last_names = load_names(female_last_names_file)
male_first_names = load_names(male_first_names_file)
male_last_names = load_names(male_last_names_file)

def getindex(file):
    # Only usable on opened file objects
    file_length = len(file.readlines())
    file.seek(0)  # Reset file pointer to the beginning
    index = random.randint(0, file_length - 1)
    return index

def gender_and_handle_full_names(words, box, image_path, device="olympus_cv_1500"):
    print("Finding out Gender and Name")
    first_name = words[0]

    d = gender.Detector()
    gender_guess = d.get_gender(first_name)
    box_to_image_map = {}

    if gender_guess in ['male', 'mostly_male']:
        name = random.choice(male_names)
        output_image_path = add_full_name_to_image(name, "male", device)
    elif gender_guess in ['female', 'mostly_female']:
        name = random.choice(female_names)
        output_image_path = add_full_name_to_image(name, "female", device)
    else:  # 'unknown' or 'andy'
        name = random.choice(female_names + male_names)
        output_image_path = add_full_name_to_image(name, "neutral", device)

    # Create a string key for the box to ensure it's hashable
    box_key = f"{box[0]},{box[1]},{box[2]},{box[3]}"
    box_to_image_map[(box_key, image_path)] = output_image_path
    return box_to_image_map

def gender_and_handle_separate_names(words, box, image_path, device="olympus_cv_1500"):
    print("Finding out Gender and Name")
    first_name = words[0]

    d = gender.Detector()
    gender_guess = d.get_gender(first_name)
    box_to_image_map = {}

    if gender_guess in ['male', 'mostly_male']:
        print("Male gender")
        with open(male_first_names_file, 'r') as file:
            index = getindex(file)
            male_first_name = male_first_names[index]
        with open(male_last_names_file, 'r') as file:
            index = getindex(file)
            male_last_name = male_last_names[index]
        name = f"{male_first_name} {male_last_name}"
        output_image_path = add_device_name_to_image(name, "male", device)
    elif gender_guess in ['female', 'mostly_female']:
        print("Female gender")
        with open(female_first_names_file, 'r') as file:
            index = getindex(file)
            female_first_name = female_first_names[index]
        with open(female_last_names_file, 'r') as file:
            index = getindex(file)
            female_last_name = female_last_names[index]
        name = f"{female_first_name} {female_last_name}"
        output_image_path = add_device_name_to_image(name, "female", device)
    else:  # 'unknown' or 'andy'
        print("Neutral or unknown gender")
        with open(neutral_first_names_file, 'r') as file:
            index = getindex(file)
            neutral_first_name = neutral_first_names[index]
        with open(neutral_last_names_file, 'r') as file:
            index = getindex(file)
            neutral_last_name = neutral_last_names[index]
        name = f"{neutral_first_name} {neutral_last_name}"
        output_image_path = add_device_name_to_image(name, "neutral", device)

    # Create a string key for the box to ensure it's hashable
    box_key = f"{box[0]},{box[1]},{box[2]},{box[3]}"
    box_to_image_map[(box_key, image_path)] = output_image_path
    return box_to_image_map
