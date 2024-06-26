from .region_detector import expand_roi
from PIL import Image
from transformers import pipeline
from transformers import ViTImageProcessor, VisionEncoderDecoderModel
import torch
import pytesseract
import numpy as np



processor = ViTImageProcessor.from_pretrained('microsoft/trocr-large-str')
model = VisionEncoderDecoderModel.from_pretrained('microsoft/trocr-large-str')
pipe = pipeline("image-to-text", model="microsoft/trocr-large-str")

def trocr_on_boxes(image_path, boxes):
    image = Image.open(image_path).convert("RGB")
    extracted_text_with_boxes = []
    confidences = []
    print("Processing image with TROCR")
    for box in boxes:
        (startX, startY, endX, endY) = box
        image_np = np.asarray(image)  # Convert the image to a NumPy array to use the shape
        image_shape = image_np.shape  # Get the shape of the image
        box = expand_roi(startX, startY, endX, endY, 5, image_shape)
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
    print("TROCR processing complete")
    return extracted_text_with_boxes, confidences


# Configure pytesseract path if necessary (specifically for Windows)
# pytesseract.pytesseract.tesseract_cmd = r'<full_path_to_your_tesseract_executable>'

def tesseract_on_boxes(image_path, boxes):
    image = Image.open(image_path).convert("RGB")
    extracted_text_with_boxes = []
    confidences = []
    print("Processing image with Tesseract OCR")
    for box in boxes:
        # Expand the region of interest using your existing function
        (startX, startY, endX, endY) = box

        image_np = np.asarray(image)  # Convert the image to a NumPy array to use the shape
        image_shape = image_np.shape  # Get the shape of the image
        box = expand_roi(startX, startY, endX, endY, 5, image_shape)
        (startX, startY, endX, endY) = box

        # Crop the image to the expanded box
        cropped_image = image.crop((startX, startY, endX, endY))

        # Use pytesseract to perform OCR on the cropped image
        ocr_result = pytesseract.image_to_string(cropped_image, config='--psm 6')

        # Get confidence scores - pytesseract also allows extracting detailed information including confidence scores
        details = pytesseract.image_to_data(cropped_image, output_type=pytesseract.Output.DICT)
        text_confidences = [int(conf) for conf in details['conf'] if type(conf) is int or (isinstance(conf, str) and conf.isdigit())]

        # Calculate the average confidence if there are any confidences available
        confidence_score = sum(text_confidences) / len(text_confidences) if text_confidences else 0

        # Append the extracted text and corresponding box to the list
        extracted_text_with_boxes.append((ocr_result.strip(), box))
        # Append the average confidence score to the confidences list
        confidences.append(confidence_score)
    print("Tesseract OCR processing complete")
    return extracted_text_with_boxes, confidences


