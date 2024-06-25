import json
import os
import cv2
from .box_operations import make_box_from_device_list

def parse_color(color_str):
    return tuple(map(int, color_str.strip('()').split(',')))

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
base_dir = os.path.dirname(os.path.abspath(__file__))

def read_device(device):
        device_file_path = os.path.join(base_dir, 'devices', f'{device}.json')
        with open(device_file_path) as json_parameters:
            data = json.load(json_parameters)
            #print("Device JSON Loaded:", data)
            keys_to_check = ["background_color", "text_color", "font", "font_size", "text_formatting", "patient_first_name_x", "patient_first_name_y", "patient_first_name_width", "patient_first_name_height", "patient_last_name_x", "patient_last_name_y", "patient_last_name_width", "patient_last_name_height"]
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
                    elif key == "patient_first_name_x":
                        first_name_x = data["fields"][key]
                    elif key == "patient_first_name_y":
                        first_name_y = data["fields"][key]
                    elif key == "patient_first_name_width":
                        first_name_width = data["fields"][key]
                    elif key == "patient_first_name_height":
                        first_name_height = data["fields"][key]
                    elif key == "patient_last_name_x":
                        last_name_x = data["fields"][key]
                    elif key == "patient_last_name_y":
                        last_name_y = data["fields"][key]
                    elif key == "patient_last_name_width":
                        last_name_width = data["fields"][key]
                    elif key == "patient_last_name_height":
                        last_name_height = data["fields"][key]
                    elif key == "text_formatting":
                        text_formatting = data["fields"][key]
            return background_color, font_color, font, font_scale, font_thickness, text_formatting, first_name_x, first_name_y, first_name_width, first_name_height, last_name_x, last_name_y, last_name_width, last_name_height, text_formatting
        

def read_name_boxes(device):
        device_file_path = os.path.join(base_dir, 'devices', f'{device}.json')
        with open(device_file_path) as json_parameters:
            data = json.load(json_parameters)
            #print("Device JSON Loaded:", data)
            keys_to_check = ["patient_first_name_x", "patient_first_name_y", "patient_first_name_width", "patient_first_name_height", "patient_last_name_x", "patient_last_name_y", "patient_last_name_width", "patient_last_name_height"]
            for key in data["fields"]:
                if key in keys_to_check:
                    if key == "patient_first_name_x":
                        first_name_x = data["fields"][key]
                    elif key == "patient_first_name_y":
                        first_name_y = data["fields"][key]
                    elif key == "patient_first_name_width":
                        first_name_width = data["fields"][key]
                    elif key == "patient_first_name_height":
                        first_name_height = data["fields"][key]
                    elif key == "patient_last_name_x":
                        last_name_x = data["fields"][key]
                    elif key == "patient_last_name_y":
                        last_name_y = data["fields"][key]
                    elif key == "patient_last_name_width":
                        last_name_width = data["fields"][key]
                    elif key == "patient_last_name_height":
                        last_name_height = data["fields"][key]
            first_name_box=make_box_from_device_list(first_name_x, first_name_y, first_name_width, first_name_height)
            last_name_box=make_box_from_device_list(last_name_x, last_name_y, last_name_width, last_name_height)
            return first_name_box, last_name_box
        
def read_background_color(device):
        device_file_path = os.path.join(base_dir, 'devices', f'{device}.json')
        with open(device_file_path) as json_parameters:
            data = json.load(json_parameters)
            #print("Device JSON Loaded:", data)
            keys_to_check = ["background_color"]
            for key in data["fields"]:
                if key in keys_to_check:
                    if key == "background_color":
                        background_color = parse_color(data["fields"][key])
            return background_color