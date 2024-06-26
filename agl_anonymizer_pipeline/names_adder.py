import cv2
import numpy as np
import uuid
import os
import time
import json
from .device_reader import read_device, read_text_formatting
from .temp_dir_setup import create_temp_directory
from .box_operations import make_box_from_device_list, make_box_from_name, extend_boxes_if_needed

# Create temporary directory
temp_dir, base_dir = create_temp_directory()
def format_name(name, format_string):
    names = name.split()
    if len(names) < 2:
        return name
    first_name = names[0]
    last_name = ' '.join(names[1:])
    formatted_name = format_string.replace("first_name", first_name).replace("last_name", last_name).replace("\n", "\n")
    return formatted_name

def validate_coordinates(coords):
    if not isinstance(coords, tuple) or len(coords) != 4:
        raise ValueError("Invalid coordinates format. Expected a tuple of four elements.")
    if not all(isinstance(coord, int) and coord >= 0 for coord in coords):
        raise ValueError("Coordinates must be non-negative integers.")

def draw_text_with_line_break(text, font, font_scale, font_color, font_thickness, background_color, first_name_coords, last_name_coords, line_spacing=20):
    validate_coordinates(first_name_coords)
    validate_coordinates(last_name_coords)
    
    padding = 10  # Padding around the text
    total_height = first_name_coords[3] + last_name_coords[3] + line_spacing + 2 * padding
    max_text_width = max(first_name_coords[2], last_name_coords[2])
    total_width = max_text_width + 2 * padding

    text_img = np.full((total_height, total_width, 3), background_color, dtype=np.uint8)

    names = text.split('\n')
    first_name = names[0]
    last_name = names[1] if len(names) > 1 else ''

    first_name_x = padding
    first_name_y = padding + first_name_coords[3]  # Adjusted for padding
    last_name_x = padding
    last_name_y = first_name_y + last_name_coords[3] + line_spacing  # Adjusted for padding and line spacing

    cv2.putText(text_img, first_name, (first_name_x, first_name_y), font, font_scale, font_color, font_thickness)
    if last_name:
        cv2.putText(text_img, last_name, (last_name_x, last_name_y), font, font_scale, font_color, font_thickness)

    return text_img
def draw_text_without_line_break(text, font, font_scale, font_color, font_thickness, background_color, first_name_coords, last_name_coords, line_spacing):
    validate_coordinates(first_name_coords)
    validate_coordinates(last_name_coords)
    
    padding = 10  # Padding around the text
    total_height = max(first_name_coords[3], last_name_coords[3]) + line_spacing + 2 * padding
    max_text_width = max(first_name_coords[2], last_name_coords[2])
    total_width = max_text_width + 2 * padding

    text_img = np.full((total_height, total_width, 3), background_color, dtype=np.uint8)

    names = text.split('\n')
    first_name = names[0]
    last_name = names[1] if len(names) > 1 else ''

    first_name_x = padding
    first_name_y = padding + first_name_coords[3]  # Adjusted for padding
    last_name_x = padding
    last_name_y = first_name_y + last_name_coords[3] + line_spacing  # Adjusted for padding and line spacing

    cv2.putText(text_img, first_name, (first_name_x, first_name_y), font, font_scale, font_color, font_thickness)
    if last_name:
        cv2.putText(text_img, last_name, (last_name_x, last_name_y), font, font_scale, font_color, font_thickness)

    return text_img

def draw_free_text(text, font, font_scale, font_color, font_thickness, background_color, first_name_coords, last_name_coords, line_spacing):
    validate_coordinates(first_name_coords)
    validate_coordinates(last_name_coords)
    
    padding = 10  # Padding around the text
    total_height = max(first_name_coords[3], last_name_coords[3]) + line_spacing + 2 * padding
    max_text_width = max(first_name_coords[2], last_name_coords[2])
    total_width = max_text_width + 2 * padding

    text_img = np.full((total_height, total_width, 3), background_color, dtype=np.uint8)

    names = text.split('\n')
    first_name = names[0]
    last_name = names[1] if len(names) > 1 else ''

    first_name_x = padding
    first_name_y = padding + first_name_coords[3]  # Adjusted for padding
    last_name_x = padding
    last_name_y = first_name_y + last_name_coords[3] + line_spacing  # Adjusted for padding and line spacing

    cv2.putText(text_img, first_name, (first_name_x, first_name_y), font, font_scale, font_color, font_thickness)
    if last_name:
        cv2.putText(text_img, last_name, (last_name_x, last_name_y), font, font_scale, font_color, font_thickness)

    return text_img

def add_device_name_to_image(name, gender_par, device=None, font=None, font_size=100, background_color=(0, 0, 0), font_color=(255, 255, 255), text_formatting=None, line_spacing=40, font_scale=1, font_thickness=2):

    try:
        background_color, font_color, font, font_scale, font_thickness, text_formatting, first_name_x, first_name_y, first_name_width, first_name_height, last_name_x, last_name_y, last_name_width, last_name_height = read_device(device)
        first_name_coords = (first_name_x, first_name_y, first_name_width, first_name_height)
        last_name_coords = (last_name_x, last_name_y, last_name_width, last_name_height)
    except (FileNotFoundError, KeyError, ValueError) as e:
        print(f"Error reading device configuration: {e}. Using default parameters.")
        first_name_coords = (50, 50, 200, 50)
        last_name_coords = (50, 110, 200, 50)
        text_formatting = "first_name last_name"

    if font is None:
        font = cv2.FONT_HERSHEY_SIMPLEX

    formatted_name = format_name(name, text_formatting)
    if "\n" in formatted_name:
        text_img = draw_text_with_line_break(formatted_name, font, font_scale, font_color, font_thickness, background_color, first_name_coords, last_name_coords, line_spacing)
    else:
        text_img = draw_text_without_line_break(formatted_name, font, font_scale, font_color, font_thickness, background_color, first_name_coords, last_name_coords, line_spacing)

    unique_id = str(uuid.uuid4())[:8]
    output_filename = f"{gender_par}_{int(time.time())}_{unique_id}.png"
    output_image_path = os.path.join(base_dir, "temp", output_filename)
    cv2.imwrite(output_image_path, text_img)
    print(f"Image saved to {output_image_path}")

    return output_image_path

def draw_text_to_fit(text, font, box, font_color, font_thickness, background_color):
    (startX, startY, endX, endY) = box
    box_width = endX - startX
    box_height = endY - startY
    
    # Create a new image with the background color
    text_img = np.full((box_height, box_width+20, 3), background_color, dtype=np.uint8)
    
    # Find the maximum font scale that fits the text height inside the box
    font_scale = 1.0
    text_size = cv2.getTextSize(text, font, font_scale, font_thickness)[0]
    while text_size[1] > box_height:
        font_scale -= 0.1
        text_size = cv2.getTextSize(text, font, font_scale, font_thickness)[0]
        if font_scale <= 0.1:  # Prevent font_scale from becoming too small
            break

    # Calculate the position to start the text
    text_x = 0  # Start at the beginning of the box (left side)
    text_y = (box_height + text_size[1]) // 2

    cv2.putText(text_img, text, (text_x, text_y), font, font_scale, font_color, font_thickness)
    return text_img, font_scale

def add_name_to_image(first_name, last_name, gender_par, first_name_box, last_name_box, device=None, font=None, font_size=100, background_color="(255, 255, 255)", font_color="(0, 0, 0)", text_formatting="first_name last_name", line_spacing=40, font_scale=1, font_thickness=2):
    try:
        background_color, font_color, font, font_scale, font_thickness, text_formatting = read_text_formatting(device)
    except (FileNotFoundError, KeyError, ValueError) as e:
        print(f"Error reading device configuration: {e}. Using default parameters.")
        text_formatting = "first_name last_name"

    if font is None:
        font = cv2.FONT_HERSHEY_SIMPLEX

    if background_color is None or font_color is None:
        background_color = "(255, 255, 255)"
        font_color = "(0, 0, 0)"

        print("Using default font and color settings.")
 
    
    if font_size is None or font_scale is None or font_thickness is None:
        font_size = 100
        font_scale = 1
        font_thickness = 2
        print("Using default font size, scale, and thickness settings.")
    
    
    formatted_name = format_name(f"{first_name} {last_name}", text_formatting)

    first_name_coords = (first_name_box[0], first_name_box[1], first_name_box[2], first_name_box[3])
    last_name_coords = (last_name_box[0], last_name_box[1], last_name_box[2], last_name_box[3])

    # Calculate the bounding box for the first name
    first_name_size = cv2.getTextSize(first_name, font, font_scale, font_thickness)[0]
    first_name_width, first_name_height = first_name_size[0], first_name_size[1]

    # Check if the first name box is too wide and adjust the last name box
    if first_name_coords[2] - first_name_coords[0] < first_name_width:
        last_name_coords = (
            first_name_coords[2] + 10,  # Move to the right of the first name box
            last_name_coords[1],
            last_name_coords[2] + (first_name_width - (first_name_coords[2] - first_name_coords[0])),  # Adjust width
            last_name_coords[3]
        )

    text_img = draw_free_text(formatted_name, font, font_scale, font_color, font_thickness, background_color, first_name_coords, last_name_coords, line_spacing)

    unique_id = str(uuid.uuid4())[:8]
    output_filename = f"{gender_par}_{int(time.time())}_{unique_id}.png"
    output_image_path = os.path.join(base_dir, "temp", output_filename)
    cv2.imwrite(output_image_path, text_img)
    print(f"Image saved to {output_image_path}")

    return output_image_path

def add_full_name_to_image(name, gender_par, box, font=None, font_size=100, background_color=(0, 0, 0), font_color=(255, 255, 255), font_scale=1, font_thickness=2):

    StartX, StartY, EndX, EndY = box
    box_width = EndX - StartX
    if font is None:
        font = cv2.FONT_HERSHEY_SIMPLEX

    text_img, font_scale = draw_text_to_fit(name, font, box, font_color, font_thickness, background_color)

    # If the text overflows the box width, we create a larger canvas
    text_size = cv2.getTextSize(name, font, font_scale, font_thickness)[0]
    if text_size[0] > box_width:
        # Create a new image with the same height but wider width to fit the text
        new_width = text_size[0] + 20  # Add some padding
        larger_text_img = np.full((text_img.shape[0], new_width, 3), background_color, dtype=np.uint8)
        larger_text_img[:, :text_img.shape[1]] = text_img  # Copy the text image to the left side
        text_img = larger_text_img

    # Generate the output filename and save the image
    unique_id = str(uuid.uuid4())[:8]
    output_filename = f"{gender_par}_{int(time.time())}_{unique_id}.png"
    output_image_path = os.path.join("temp", output_filename)
    cv2.imwrite(output_image_path, text_img)
    print(f"Image saved to {output_image_path}")

    return output_image_path