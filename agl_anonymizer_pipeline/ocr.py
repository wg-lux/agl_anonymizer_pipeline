from .region_detector import expand_roi  # Ensure this module is correctly referenced
from PIL import Image
from transformers import (
    ViTImageProcessor,
    VisionEncoderDecoderModel,
    AutoTokenizer,
    pipeline
)
import torch
import pytesseract
import numpy as np

def preload_models():
    global processor, model, tokenizer, device

    print("Preloading models...")

    # Determine the device
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {device}")

    # Load processor, model, and tokenizer
    processor = ViTImageProcessor.from_pretrained('microsoft/trocr-base-str')
    model = VisionEncoderDecoderModel.from_pretrained('microsoft/trocr-base-str')
    tokenizer = AutoTokenizer.from_pretrained('microsoft/trocr-base-str')

    # Move the model to the appropriate device
    model.to(device)

    # Optionally, set up the pipeline if you intend to use it
    # However, using both the pipeline and direct model calls can lead to confusion
    # It's recommended to choose one method. Below is commented out to avoid conflicts.
    # pipe = pipeline(
    #     "image-to-text",
    #     model=model,
    #     tokenizer=tokenizer,
    #     feature_extractor=processor,
    #     device=0 if torch.cuda.is_available() else -1
    # )

    print("Models preloaded successfully.")
    return processor, model, tokenizer, device

def trocr_on_boxes(image_path, boxes):
    image = Image.open(image_path).convert("RGB")
    extracted_text_with_boxes = []
    confidences = []

    # Ensure models are loaded
    processor, model, tokenizer, device = preload_models()

    print("Processing image with TrOCR")

    for idx, box in enumerate(boxes):
        try:
            (startX, startY, endX, endY) = box

            # Expand the region of interest
            image_np = np.asarray(image)
            image_shape = image_np.shape
            expanded_box = expand_roi(startX, startY, endX, endY, 5, image_shape)
            (startX_exp, startY_exp, endX_exp, endY_exp) = expanded_box

            # Crop the image to the expanded box
            cropped_image = image.crop((startX_exp, startY_exp, endX_exp, endY_exp))

            # Process the cropped image using the processor
            pixel_values = processor(
                cropped_image, 
                return_tensors="pt"
            ).pixel_values

            # Move pixel_values to the same device as the model
            pixel_values = pixel_values.to(device)

            # Generate text predictions using the model
            outputs = model.generate(
                pixel_values, 
                output_scores=True, 
                return_dict_in_generate=True, 
                max_new_tokens=50
            )

            # Decode the output tokens into readable text
            generated_text = tokenizer.batch_decode(
                outputs.sequences, 
                skip_special_tokens=True
            )[0]

            # Calculate confidence score from the last token's scores
            scores = outputs.scores  # List of logits for each generation step
            if scores:
                # Take the scores from the last generation step
                last_scores = scores[-1]
                confidence_score = torch.nn.functional.softmax(last_scores, dim=-1).max().item()
            else:
                confidence_score = 0.0  # Default confidence if scores are unavailable

            # Append results to the lists
            extracted_text_with_boxes.append((generated_text.strip(), expanded_box))
            confidences.append(confidence_score)

            print(f"Processed box {idx + 1}/{len(boxes)}: '{generated_text.strip()}' with confidence {confidence_score:.4f}")

        except Exception as e:
            print(f"Error processing box {idx + 1}/{len(boxes)}: {e}")
            extracted_text_with_boxes.append(("", box))
            confidences.append(0.0)

    print("TrOCR processing complete")
    return extracted_text_with_boxes, confidences

def tesseract_on_boxes(image_path, boxes):
    image = Image.open(image_path).convert("RGB")
    extracted_text_with_boxes = []
    confidences = []

    print("Processing image with Tesseract OCR")

    for idx, box in enumerate(boxes):
        try:
            (startX, startY, endX, endY) = box

            # Expand the region of interest
            image_np = np.asarray(image)
            image_shape = image_np.shape
            expanded_box = expand_roi(startX, startY, endX, endY, 5, image_shape)
            (startX_exp, startY_exp, endX_exp, endY_exp) = expanded_box

            # Crop the image to the expanded box
            cropped_image = image.crop((startX_exp, startY_exp, endX_exp, endY_exp))

            # Use pytesseract to perform OCR on the cropped image
            ocr_result = pytesseract.image_to_string(cropped_image, config='--psm 6')

            # Get confidence scores from pytesseract
            details = pytesseract.image_to_data(cropped_image, output_type=pytesseract.Output.DICT)
            text_confidences = [
                int(conf) for conf in details['conf'] 
                if isinstance(conf, (int, str)) and str(conf).isdigit()
            ]

            # Calculate the average confidence score
            confidence_score = sum(text_confidences) / len(text_confidences) if text_confidences else 0.0

            # Append results to the lists
            extracted_text_with_boxes.append((ocr_result.strip(), expanded_box))
            confidences.append(confidence_score)

            print(f"Processed box {idx + 1}/{len(boxes)}: '{ocr_result.strip()}' with confidence {confidence_score:.2f}")

        except Exception as e:
            print(f"Error processing box {idx + 1}/{len(boxes)}: {e}")
            extracted_text_with_boxes.append(("", box))
            confidences.append(0.0)

    print("Tesseract OCR processing complete")
    return extracted_text_with_boxes, confidences

if __name__ == "__main__":
    # Preload models once when the script runs
    processor, model, tokenizer, device = preload_models()
    
    # Example usage:
    # Define your image path and bounding boxes
    image_path = "path/to/your/image.jpg"
    boxes = [
        (50, 50, 200, 150),
        (250, 80, 400, 180),
        # Add more boxes as needed
    ]
    
    # Perform OCR using TrOCR
    trocr_results, trocr_confidences = trocr_on_boxes(image_path, boxes)
    print("TrOCR Results:", trocr_results)
    print("TrOCR Confidences:", trocr_confidences)
    
    # Perform OCR using Tesseract
    tesseract_results, tesseract_confidences = tesseract_on_boxes(image_path, boxes)
    print("Tesseract Results:", tesseract_results)
    print("Tesseract Confidences:", tesseract_confidences)
