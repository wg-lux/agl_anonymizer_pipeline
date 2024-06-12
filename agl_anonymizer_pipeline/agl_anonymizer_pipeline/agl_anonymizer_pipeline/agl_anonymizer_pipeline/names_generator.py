import os
import cv2
import numpy as np
import random
import gender_guesser.detector as gender
import time
import uuid
import json

# Define the base directory and file paths
base_dir = os.path.dirname(os.path.abspath(__file__))
female_names_file = os.path.join(base_dir, 'names_dict', 'first_and_last_name_female.txt')
male_names_file = os.path.join(base_dir, 'names_dict', 'first_and_last_name_male.txt')
female_first_names_file = os.path.join(base_dir, 'names_dict', 'first_names_female.txt')
female_last_names_file = os.path.join(base_dir, 'names_dict', 'last_names_female.txt')
neutral_first_names_file = os.path.join(base_dir, 'names_dict', 'first_names_neutral.txt')
neutral_last_names_file = os.path.join(base_dir, 'names_dict', 'last_names_neutral.txt')
male_first_names_file = os.path.join(base_dir, 'names_dict', 'first_names_male.txt')
male_last_names_file = os.path.join(base_dir, 'names_dict', 'last_names_male.txt')

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

# Font mapping
FONT_MAP = {
    "FONT_HERSHEY_SIMPLEX": cv2.FONT_HERSHEY_SIMPLEX,
    "FONT_HERSHEY_PLAIN": cv2.FONT_HERSHEY_PLAIN,
    "FONT_HERSHEY_DUPLEX": cv2.FONT_HERSHEY_DUPLEX,
    "FONT_HERSHEY_COMPLEX": cv2.FONT_HERSHEY_COMPLEX,
    "FONT_HERSHEY_TRIPLEX": cv2.FONT_HERSHEY_TRIPLEX,
    "FONT_HERSHEY_COMPLEX_SMALL": cv2.FONT_HERSHEY_COMPLEX_SMALL,
    "FONT_HERSHEY_SCRIPT_SIMPLEX": cv2.FONT_HERSHEY_SCRIPT_SIMPLEX,
    "FONT_HERSHEY_SCRIPT_COMPLEX": cv2.FONT_HERSHEY_SCRIPT_COMPLEX
}

# Add name to image function
def add_name_to_image(name, gender_par, device="olympus_cv_1500", font=None, text_size=None, background_color=(0, 0, 0), font_color=(255, 255, 255), text_formatting=None):
    def parse_color(color_str):
        return tuple(map(int, color_str.strip('()').split(',')))

    def format_name(full_name, format_string):
        names = full_name.split()
        if len(names) < 2:
            return full_name
        first_name = names[0]
        last_name = ' '.join(names[1:])
        formatted_name = format_string.replace("first_name", first_name).replace("last_name", last_name).replace("/n", "\n")
        return formatted_name

    def draw_text(text, font, font_scale, font_color, font_thickness, background_color):
        # Split text into lines
        lines = text.split('\n')
        text_height = 0
        text_width = 0
        line_sizes = []

        # Calculate the size of each line
        for line in lines:
            line_size = cv2.getTextSize(line, font, font_scale, font_thickness)[0]
            text_width = max(text_width, line_size[0])
            text_height += line_size[1] + 10  # Adding line spacing
            line_sizes.append(line_size)

        # Create a new image with the background color
        text_img = np.full((text_height + 20, text_width + 20, 3), background_color, dtype=np.uint8)

        # Draw each line on the new image
        y = 10
        for line, size in zip(lines, line_sizes):
            cv2.putText(text_img, line, (10, y + size[1]), font, font_scale, font_color, font_thickness)
            y += size[1] + 10

        return text_img

    try:
        device_file_path = os.path.join(base_dir, 'devices', f'{device}.json')
        with open(device_file_path) as json_parameters:
            data = json.load(json_parameters)
            print("Device JSON Loaded:", data)
            keys_to_check = ["background_color", "text_color", "font", "font_size", "text_formatting"]
            for key in data["fields"]:
                if key in keys_to_check:
                    if key == "background_color":
                        background_color = parse_color(data["fields"][key])
                    elif key == "text_color":
                        font_color = parse_color(data["fields"][key])
                    elif key == "font":
                        font_key = data["fields"][key]
                        if font_key in FONT_MAP:
                            font = FONT_MAP[font_key]
                        else:
                            print(f"Warning: Font '{font_key}' not recognized. Using default font.")
                            font = cv2.FONT_HERSHEY_SIMPLEX
                    elif key == "font_size":
                        font_size = data["fields"][key]
                        font_scale = font_size / 20
                        font_thickness = 2
                    elif key == "text_formatting":
                        text_formatting = data["fields"][key]
            print(f"Formatted name: {name}, Font: {font}, Font Scale: {font_scale}, Font Thickness: {font_thickness}, Font Color: {font_color}, Background Color: {background_color}")
    except FileNotFoundError:
        print("Device not found in device list. Using default parameters.")
        return None

    if font is None:
        font = cv2.FONT_HERSHEY_SIMPLEX
        font_scale = 1
        font_thickness = 2

    if text_size is not None:
        font_scale = text_size[0]
        font_thickness = text_size[1]

    # Format the name according to the text formatting
    formatted_name = format_name(name, text_formatting)
    print(f"Formatted name: {formatted_name}")

    # Create the text image
    text_img = draw_text(formatted_name, font, font_scale, font_color, font_thickness, background_color)

    unique_id = str(uuid.uuid4())[:8]
    output_filename = f"{gender_par}_{int(time.time())}_{unique_id}.png"
    output_image_path = os.path.join(base_dir, "temp", output_filename)
    cv2.imwrite(output_image_path, text_img)
    print(f"Image saved to {output_image_path}")

    return output_image_path

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
        output_image_path = add_name_to_image(name, "male", device)
    elif gender_guess in ['female', 'mostly_female']:
        name = random.choice(female_names)
        output_image_path = add_name_to_image(name, "female", device)
    else:  # 'unknown' or 'andy'
        name = random.choice(female_names + male_names)
        output_image_path = add_name_to_image(name, "neutral", device)

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
        output_image_path = add_name_to_image(name, "male", device)
    elif gender_guess in ['female', 'mostly_female']:
        print("Female gender")
        with open(female_first_names_file, 'r') as file:
            index = getindex(file)
            female_first_name = female_first_names[index]
        with open(female_last_names_file, 'r') as file:
            index = getindex(file)
            female_last_name = female_last_names[index]
        name = f"{female_first_name} {female_last_name}"
        output_image_path = add_name_to_image(name, "female", device)
    else:  # 'unknown' or 'andy'
        print("Neutral or unknown gender")
        with open(neutral_first_names_file, 'r') as file:
            index = getindex(file)
            neutral_first_name = neutral_first_names[index]
        with open(neutral_last_names_file, 'r') as file:
            index = getindex(file)
            neutral_last_name = neutral_last_names[index]
        name = f"{neutral_first_name} {neutral_last_name}"
        output_image_path = add_name_to_image(name, "neutral", device)

    # Create a string key for the box to ensure it's hashable
    box_key = f"{box[0]},{box[1]},{box[2]},{box[3]}"
    box_to_image_map[(box_key, image_path)] = output_image_path
    return box_to_image_map
