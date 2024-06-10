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
        outputs = model.generate(pixel_values, output_scores=True, return_dict_in_generate=True)
        
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
                # image_paths = convert_pdf_to_images(pdf_data)

                # Open the PDF again for text extraction
                with fitz.open(stream=pdf_data, filetype="pdf") as doc:
                    text = ""
                    for page in doc:
                        text += page.get_text()
                    extracted_text = text

            for img_path in image_paths:
                print("PDF split into images")
                boxes, east_confidences = east_text_detection(img_path, east_path, min_confidence, width, height)
                print("Text boxes detected")

                extracted_text_with_boxes, ocr_confidences = ocr_on_boxes(img_path, boxes)

                for (phrase, phrase_box), ocr_confidence in zip(extracted_text_with_boxes, ocr_confidences):
                    processed_text = process_text(phrase)
                    entities = NER_German(processed_text)
                    if entities is None:
                        entities = []

                    entity_info = [(entity.text, entity.tag) for entity in entities if entity.tag == 'PER']

                    combined_results.append((phrase, phrase_box, ocr_confidence, entity_info))
                    if device == "olympus_cv_1500":
                        for entity in entity_info:
                            names_detected.append(entity[0])
                            box_to_image_map = gender_and_handle_separate_names([entity[0]], phrase_box, img_path, device)
                            for box_key, modified_image_path in box_to_image_map.items():
                                modified_images_map[(box_key, img_path)] = modified_image_path
                    else:
                        for entity in entity_info:
                            names_detected.append(entity[0])
                            box_to_image_map = gender_and_handle_full_names([entity[0]], phrase_box, img_path, device)
                            for box_key, modified_image_path in box_to_image_map.items():
                                modified_images_map[(box_key, img_path)] = modified_image_path

        else:
            boxes, east_confidences = east_text_detection(file_path, east_path, min_confidence, width, height)
            print("Text boxes detected")

            extracted_text_with_boxes, ocr_confidences = ocr_on_boxes(file_path, boxes)

            for (phrase, phrase_box), ocr_confidence in zip(extracted_text_with_boxes, ocr_confidences):
                processed_text = process_text(phrase)
                entities = NER_German(processed_text)
                if entities is None:
                    entities = []

                entity_info = [(entity.text, entity.tag) for entity in entities if entity.tag == 'PER']

                combined_results.append((phrase, phrase_box, ocr_confidence, entity_info))
                if device == "olympus_cv_1500":
                    for entity in entity_info:
                        names_detected.append(entity[0])
                        box_to_image_map = gender_and_handle_separate_names([entity[0]], phrase_box, file_path, device)
                        for box_key, modified_image_path in box_to_image_map.items():
                            modified_images_map[(box_key, file_path)] = modified_image_path
                else:
                    for entity in entity_info:
                        names_detected.append(entity[0])
                        box_to_image_map = gender_and_handle_full_names([entity[0]], phrase_box, file_path, device)
                        for box_key, modified_image_path in box_to_image_map.items():
                            modified_images_map[(box_key, file_path)] = modified_image_path

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

# Example usage
if __name__ == "__main__":
    file_path = "your_file_path.jpg"
    modified_images_map, result = process_images_with_OCR_and_NER(file_path)
    for res in result['combined_results']:
        print(res)
