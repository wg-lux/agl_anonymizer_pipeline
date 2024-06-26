from .ocr import trocr_on_boxes, tesseract_on_boxes
from .flair_NER import NER_German
from .names_generator import gender_and_handle_full_names, gender_and_handle_separate_names, gender_and_handle_device_names
import fitz
from .east_text_detection import east_text_detection
import re
from .pdf_operations import convert_pdf_to_images
from .blur import blur_function
from .device_reader import read_name_boxes, read_background_color
from .tesseract_text_detection import tesseract_text_detection
import cv2
import json


def find_or_create_close_box(phrase_box, boxes, image_width, offset=60):
    """
    Finds the closest box on the same line or creates a new box close to the phrase_box.

    Parameters:
    phrase_box: tuple
        The coordinates of the phrase box (startX, startY, endX, endY).
    boxes: list
        A list of existing boxes to check.
    image_width: int
        The width of the image to ensure new boxes are within the image bounds.
    offset: int
        The fixed offset to create a new box if no existing box is close.

    Returns:
    tuple
        The coordinates of the found or created close box (startX, startY, endX, endY).
    """
    (startX, startY, endX, endY) = phrase_box
    same_line_boxes = [box for box in boxes if abs(box[1] - startY) <= 10]

    if same_line_boxes:
        # Sort by proximity to the right of the phrase_box
        same_line_boxes.sort(key=lambda box: box[0])
        for box in same_line_boxes:
            if box[0] > endX:
                return box

    # If no box is found or all are to the left, create a new box
    new_startX = min(endX + offset, image_width)
    new_endX = new_startX + (endX - startX)
    new_box = (new_startX, startY, new_endX, endY)
    return new_box

def combine_boxes(text_with_boxes):
    if not text_with_boxes:
        return text_with_boxes

    # Sort the boxes by (startY, startX)
    text_with_boxes = sorted(text_with_boxes, key=lambda x: (x[1][1], x[1][0]))

    merged_text_with_boxes = [text_with_boxes[0]]

    for current in text_with_boxes[1:]:
        last = merged_text_with_boxes[-1]

        # Unpack current and last
        current_text, current_box = current
        last_text, last_box = last

        (last_startX, last_startY, last_endX, last_endY) = last_box
        (current_startX, current_startY, current_endX, current_endY) = current_box

        # Check if the boxes are on the same line and close enough to merge
        if last_startY == current_startY and (current_startX - last_endX) <= 10:
            # Merge the boxes
            merged_box = (min(last_startX, current_startX), last_startY, max(last_endX, current_endX), last_endY)
            # Concatenate the text
            merged_text = last_text + ' ' + current_text
            # Update the last entry in the merged list
            merged_text_with_boxes[-1] = (merged_text, merged_box)
        else:
            # Add the current box as a new entry
            merged_text_with_boxes.append(current)

    return merged_text_with_boxes

def process_images_with_OCR_and_NER(file_path, east_path='frozen_east_text_detection.pb', device="default", min_confidence=0.5, width=320, height=320):
    print("Processing file:", file_path)
    modified_images_map = {}
    combined_results = []
    names_detected = []

    try:
        
        # Determine the file type
        file_extension = file_path.split('.')[-1].lower()
        mime_types = {
            'jpg': 'image/jpeg',
            'jpeg': 'image/jpeg',
            'png': 'image/png',
            'gif': 'image/gif',
            'bmp': 'image/bmp',
            'tiff': 'image/tiff',
            'pdf': 'application/pdf',
        }
        file_type = mime_types.get(file_extension, 'application/octet-stream').split('/')[-1]

        if file_type not in ['jpg', 'jpeg', 'png', 'tiff', 'pdf']:
            raise ValueError('Invalid file type.')

        image_paths = [file_path]
        extracted_text = ''

        if file_type == 'pdf':
            with open(file_path, 'rb') as pdf_file:
                pdf_data = pdf_file.read()
                image_paths = convert_pdf_to_images(pdf_data)
                with fitz.open(stream=pdf_data, filetype="pdf") as doc:
                    extracted_text = " ".join([page.get_text() for page in doc])

        for img_path in image_paths:
            print("Processing image:", img_path)
            try:
                first_name_box, last_name_box = read_name_boxes(device)
                background_color = read_background_color(device)
            except Exception as e:
                print(f"Using default values for name replacement.")
                first_name_box, last_name_box = None, None
                background_color = "(0, 0, 0)"
            if first_name_box and last_name_box:
                # Apply blur functions
                img_path = blur_function(img_path, first_name_box, background_color)
                img_path = blur_function(img_path, last_name_box, background_color)

            # Detect text boxes using EAST and Tesseract
            east_boxes, east_confidences_json = east_text_detection(img_path, east_path, min_confidence, width, height)


            tesseract_boxes, tesseract_confidences = tesseract_text_detection(img_path, min_confidence, width, height)

            # Combine the boxes and confidences
            combined_boxes = east_boxes + tesseract_boxes
            #combined_confidences = east_confidences + tesseract_confidences

            # OCR with both pipelines
            print("Running OCR on boxes")
            trocr_results, trocr_confidences = trocr_on_boxes(img_path, combined_boxes)
            tesseract_results, tess_confidences = tesseract_on_boxes(img_path, combined_boxes)

            # Combine all OCR results
            all_ocr_results = trocr_results + tesseract_results
            all_ocr_confidences = trocr_confidences + tess_confidences
            if device is not None:
                try:
                    first_name_box, last_name_box = read_name_boxes(device)
                except Exception as e:
                    print(f"Using default values for name replacement.")
                    first_name_box, last_name_box = None, None
            else:
                first_name_box, last_name_box = None, None
            # Process each OCR result
            for (phrase, phrase_box), ocr_confidence in zip(all_ocr_results, all_ocr_confidences):
                process_ocr_results(img_path, phrase, phrase_box, ocr_confidence, combined_results, names_detected, device, modified_images_map, combined_boxes, first_name_box, last_name_box)

        result = {
            'filename': file_path,
            'file_type': file_type,
            'extracted_text': extracted_text,
            'names_detected': names_detected,
            'combined_results': combined_results,
            #'east_confidences': east_confidences  # Assuming you want to track this separately
        }

        print("Processing completed:", combined_results)
        return modified_images_map, result

    except Exception as e:
        error_message = f"Error in process_images_with_OCR_and_NER: {e}, File Path: {file_path}"
        print(error_message)
        raise RuntimeError(error_message)
    

def process_text(extracted_text):
    # Replace two or more consecutive "\n" characters with a single "\n"
    cleaned_text = re.sub(r'\n{2,}', '\n', extracted_text)
    # Replace remaining "\n" characters with a space
    cleaned_text = cleaned_text.replace("\n", " ")
    return cleaned_text

def process_ocr_results(image_path, phrase, phrase_box, ocr_confidence, combined_results, names_detected, device, modified_images_map, combined_boxes, first_name_box=None, last_name_box=None):
    processed_text = process_text(phrase)
    entities = split_and_check(processed_text)

    print(f"Entities detected: {entities}")

    (startX, startY, endX, endY) = phrase_box
    box_to_image_map = {}

    for entity in entities:
        name = entity[0]
        current_image_path = image_path  # Use a local variable to handle image modifications

        if first_name_box and last_name_box:
            if close_to_box(first_name_box, phrase_box) or close_to_box(last_name_box, phrase_box):
                box_to_image_map = gender_and_handle_device_names(name, phrase_box, current_image_path, device)
            else:
                current_image_path = modify_image_for_name(current_image_path, phrase_box, combined_boxes)
                box_to_image_map = gender_and_handle_separate_names(name, phrase_box, last_name_box, current_image_path, device)
        else:
            current_image_path = modify_image_for_name(current_image_path, phrase_box, combined_boxes)
            box_to_image_map = gender_and_handle_separate_names(name, phrase_box, last_name_box, current_image_path, device)

        names_detected.append(name)
        for box_key, modified_image_path in box_to_image_map.items():
            modified_images_map[(box_key, current_image_path)] = modified_image_path

    combined_results.append((phrase, phrase_box, ocr_confidence, entities))


def close_to_box(name_box, phrase_box):
    (startX, startY, _, _) = phrase_box
    return abs(name_box[0] - startX) <= 10 and abs(name_box[1] - startY) <= 10


def modify_image_for_name(image_path, phrase_box, combined_boxes):
    image = cv2.imread(image_path)
    image_width = image.shape[1]
    last_name_box = find_or_create_close_box(phrase_box, combined_boxes, image_width)
    return blur_function(image_path, phrase_box)

def split_and_check(phrase):
    entities = NER_German(phrase)
    if entities:
        return [(entity.text, entity.tag) for entity in entities if entity.tag == 'PER']
    parts = [phrase[:3], phrase[-3:], phrase[:4] + phrase[-4:], phrase[:5] + phrase[-5:], phrase[:6] + phrase[-6:]]
    for part in parts:
        entities = NER_German(part)
        if entities:
            return [(entity.text, entity.tag) for entity in entities if entity.tag == 'PER']
    return []


# Example usage
if __name__ == "__main__":
    file_path = "your_file_path.jpg"
    modified_images_map, result = process_images_with_OCR_and_NER(file_path)
    for res in result['combined_results']:
        print(res)
