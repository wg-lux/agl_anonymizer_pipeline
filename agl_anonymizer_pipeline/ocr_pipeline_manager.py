from transformers import pipeline
from transformers import ViTImageProcessor, VisionEncoderDecoderModel
from PIL import Image
from .flair_NER import NER_German
from .names_generator import gender_and_handle_full_names, gender_and_handle_separate_names
import fitz
from .east_text_detection import east_text_detection
import os
import re
import torch
from .pdf_operations import convert_pdf_to_images
from .blur import blur_function
from .device_reader import read_name_boxes, read_background_color
import cv2
import json
from .region_detector import expand_roi
from .tesseract_text_detection import tesseract_text_detection

processor = ViTImageProcessor.from_pretrained('microsoft/trocr-large-str')
model = VisionEncoderDecoderModel.from_pretrained('microsoft/trocr-large-str')
pipe = pipeline("image-to-text", model="microsoft/trocr-large-str")

def ocr_on_boxes(image_path, boxes):
    image = Image.open(image_path).convert("RGB")
    extracted_text_with_boxes = []
    confidences = []

    for box in boxes:
        (startX, startY, endX, endY) = box
        cropped_image = image.crop((startX, startY, endX, endY))
        pixel_values = processor(cropped_image, return_tensors="pt").pixel_values
        outputs = model.generate(pixel_values, output_scores=True, return_dict_in_generate=True, max_new_tokens=50)
        
        scores = outputs.scores

        # Simplified confidence score calculation
        confidence_score = torch.nn.functional.softmax(scores[-1], dim=-1).max().item()
        
        # Process cropped image with the OCR pipeline
        ocr_results = pipe(cropped_image, max_new_tokens=50)

        # Initialize an empty string to store concatenated text
        concatenated_text = ''

        # Iterate over each result and concatenate the 'generated_text'
        for result in ocr_results:
            if 'generated_text' in result:
                concatenated_text += ' ' + result['generated_text']

        # Append the concatenated text and corresponding box to the list
        extracted_text_with_boxes.append((concatenated_text.strip(), box))
        # Append the confidence score to the confidences list
        confidences.append(confidence_score)

    return extracted_text_with_boxes, confidences

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

def process_images_with_OCR_and_NER(file_path, east_path='frozen_east_text_detection.pb', device="olympus_cv_1500", min_confidence=0.5, width=320, height=320):
    print("Processing file:", file_path)

    # Initialize variables
    modified_images_map = {}
    combined_results = []
    names_detected = []
    extracted_text = ''

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

        if file_type == 'pdf':
            image_paths = []

            # Open the PDF file from the file path
            with open(file_path, 'rb') as pdf_file:
                pdf_data = pdf_file.read()

                # Convert the entire PDF to images
                image_paths = convert_pdf_to_images(pdf_data)

                # Open the PDF again for text extraction
                with fitz.open(stream=pdf_data, filetype="pdf") as doc:
                    text = ""
                    for page in doc:
                        text += page.get_text()
                    extracted_text = text

            for img_path in image_paths:
                if device is not None:
                    first_name_box, last_name_box = read_name_boxes(device)
                    background_color = read_background_color(device)
                file_path = blur_function(file_path, first_name_box, background_color)
                file_path = blur_function(file_path, last_name_box, background_color)
                print("PDF split into images")
                east_boxes, east_confidences_json = east_text_detection(img_path, east_path, min_confidence, width, height)
                east_confidences = json.loads(east_confidences_json)
                print("Text boxes detected")

                # Append Tesseract OCR boxes
                tesseract_boxes, _ = tesseract_text_detection(img_path, min_confidence, width, height)
                combined_boxes = east_boxes + tesseract_boxes

                extracted_text_with_boxes, ocr_confidences = ocr_on_boxes(img_path, combined_boxes)
                merged_text_with_boxes = combine_boxes(extracted_text_with_boxes)

                for (phrase, phrase_box), ocr_confidence in zip(merged_text_with_boxes, ocr_confidences):
                    process_ocr_results(img_path, phrase, phrase_box, ocr_confidence, combined_results, names_detected, device, modified_images_map)

        else:
            if device is not None:
                first_name_box, last_name_box = read_name_boxes(device)
                background_color = read_background_color(device)
                file_path = blur_function(file_path, first_name_box, background_color)
                file_path = blur_function(file_path, last_name_box, background_color)
            east_boxes, east_confidences_json = east_text_detection(file_path, east_path, min_confidence, width, height)
            east_confidences = json.loads(east_confidences_json)
            print("Text boxes detected")

            # Append Tesseract OCR boxes
            tesseract_boxes, _ = tesseract_text_detection(file_path, min_confidence, width, height)
            combined_boxes = east_boxes + tesseract_boxes

            extracted_text_with_boxes, ocr_confidences = ocr_on_boxes(file_path, combined_boxes)
            merged_text_with_boxes = combine_boxes(extracted_text_with_boxes)

            for (phrase, phrase_box), ocr_confidence in zip(merged_text_with_boxes, ocr_confidences):
                process_ocr_results(file_path, phrase, phrase_box, ocr_confidence, combined_results, names_detected, device, modified_images_map)

        result = {
            'filename': file_path,
            'file_type': file_type,
            'extracted_text': extracted_text,
            'names_detected': names_detected,
            'combined_results': combined_results,
            'east_confidences': east_confidences
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

def process_ocr_results(image_path, phrase, phrase_box, ocr_confidence, combined_results, names_detected, device, modified_images_map):
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

    processed_text = process_text(phrase)
    entities = split_and_check(processed_text)
        
    combined_results.append((phrase, phrase_box, ocr_confidence, entities))
    if device is not None:
        first_name_box, last_name_box = read_name_boxes(device)
        background_color = read_background_color(device)
        print(f"background_color: {background_color}")

    else:
        first_name_box, last_name_box = None, None
        background_color = (0, 0, 0)

    print(f"Phrase Box: {phrase_box}")
    print(f"First Name Box: {first_name_box}, Last Name Box: {last_name_box}")

    (startX, startY, endX, endY) = phrase_box
    
    if first_name_box and last_name_box:
        if (first_name_box[0] - startX <= 10 and first_name_box[1] - startY <= 10) or (last_name_box[0] - startX <= 10 and last_name_box[1] - startY <= 10):
            for entity in entities:
                names_detected.append(entity[0])
                box_to_image_map = gender_and_handle_separate_names([entity[0]], phrase_box, image_path, device)
                for box_key, modified_image_path in box_to_image_map.items():
                    modified_images_map[(box_key, image_path)] = modified_image_path
        else:
            for entity in entities:
                names_detected.append(entity[0])
                image_path = blur_function(image_path, phrase_box)
                box_to_image_map = gender_and_handle_full_names([entity[0]], phrase_box, image_path, device)
                for box_key, modified_image_path in box_to_image_map.items():
                    modified_images_map[(box_key, image_path)] = modified_image_path
    else:
        for entity in entities:
            names_detected.append(entity[0])
            box_to_image_map = gender_and_handle_full_names([entity[0]], phrase_box, image_path, device)
            for box_key, modified_image_path in box_to_image_map.items():
                modified_images_map[(box_key, image_path)] = modified_image_path

# Example usage
if __name__ == "__main__":
    file_path = "your_file_path.jpg"
    modified_images_map, result = process_images_with_OCR_and_NER(file_path)
    for res in result['combined_results']:
        print(res)
