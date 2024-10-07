import cv2
import uuid
import os
import tempfile
import logging
from .ocr_pipeline_manager import process_images_with_OCR_and_NER
from .pdf_operations import convert_pdf_page_to_image, merge_pdfs, convert_image_to_pdf
from .image_reassembly import reassemble_image
import torch
from .directory_setup import create_temp_directory
import pymupdf  # PyMuPDF

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

def resize_image(image_path, max_width=1024, max_height=1024):
    image = cv2.imread(image_path)
    if image is None:
        logger.error(f"Unable to read image for resizing: {image_path}")
        return
    height, width = image.shape[:2]
    if width > max_width or height > max_height:
        scaling_factor = min(max_width / width, max_height / height)
        new_size = (int(width * scaling_factor), int(height * scaling_factor))
        resized_image = cv2.resize(image, new_size, interpolation=cv2.INTER_AREA)
        cv2.imwrite(image_path, resized_image)
        logger.debug(f"Image resized to {new_size}")

def clear_gpu_memory():
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        logger.debug("Cleared GPU memory.")

def get_image_paths(image_or_pdf_path, temp_dir):
    image_paths = []

    if image_or_pdf_path.lower().endswith('.pdf'):
        doc = pymupdf.open(image_or_pdf_path)
        for page_num in range(len(doc)):
            page = doc[page_num]
            pix = page.get_pixmap()
            temp_img_path = os.path.join(temp_dir, f"page_{page_num}.png")
            pix.save(temp_img_path)
            image_paths.append(temp_img_path)
    else:
        image_paths.append(image_or_pdf_path)

    return image_paths

def process_image(image_path, east_path, device, min_confidence, width, height, results_dir, temp_dir):
    logger.info(f"Processing file: {image_path}")
    unique_id = str(uuid.uuid4())[:8]
    id = f"image_{unique_id}"

    original_image = cv2.imread(image_path)
    if original_image is None:
        error_msg = f"Could not load image at {image_path}"
        logger.error(error_msg)
        raise ValueError(error_msg)

    try:
        resize_image(image_path)  # Resize to manage memory
        modified_images_map, result = process_images_with_OCR_and_NER(
            image_path, east_path, device, min_confidence, width, height
        )
        logger.info("Images processed")
        logger.debug(f"Modified Images Map: {modified_images_map}")

        reassembled_image_path = reassemble_image(modified_images_map, results_dir, id, image_path)
        return reassembled_image_path, result
    except Exception as e:
        error_message = f"Error in process_image: {e}, Image Path: {image_path}"
        logger.error(error_message)
        raise RuntimeError(error_message)
    finally:
        clear_gpu_memory()

def main(image_or_pdf_path, east_path=None, device="olympus_cv_1500", validation=False, min_confidence=0.5, width=320, height=320):
    clear_gpu_memory()
    temp_dir, base_dir, csv_dir = create_temp_directory()

    results_dir = os.path.join(os.path.dirname(image_or_pdf_path), "results")
    os.makedirs(results_dir, exist_ok=True)

    image_paths = get_image_paths(image_or_pdf_path, temp_dir)

    processed_pdf_paths = []
    result = None
    try:
        for img_path in image_paths:
            try:
                processed_image_path, result = process_image(
                    img_path, east_path, device, min_confidence, width, height, results_dir, temp_dir
                )
                if image_or_pdf_path.lower().endswith('.pdf'):
                    temp_pdf_path = os.path.join(temp_dir, f"processed_{uuid.uuid4()}.pdf")
                    convert_image_to_pdf(processed_image_path, temp_pdf_path)
                    processed_pdf_paths.append(temp_pdf_path)
                else:
                    processed_pdf_paths.append(processed_image_path)
            except Exception as e:
                error_message = f"Error processing {img_path}: {e}"
                logger.error(error_message)

        if not processed_pdf_paths:
            error_message = "No processed images were generated."
            logger.error(error_message)
            raise RuntimeError(error_message)

        if image_or_pdf_path.lower().endswith('.pdf'):
            final_pdf_path = os.path.join(results_dir, "final_document.pdf")
            merge_pdfs(processed_pdf_paths, final_pdf_path)
            output_path = final_pdf_path
        else:
            output_path = processed_pdf_paths[0]
    finally:
        # Clean up temporary directory
        for file in os.listdir(temp_dir):
            try:
                os.remove(os.path.join(temp_dir, file))
            except Exception as e:
                logger.warning(f"Failed to delete temp file {file}: {e}")
        try:
            os.rmdir(temp_dir)
        except Exception as e:
            logger.warning(f"Failed to delete temp directory {temp_dir}: {e}")

    logger.info(f"Output Path: {output_path}")
    if not validation:
        return output_path  # Return only the output path
    else:
        return output_path, result, image_or_pdf_path  # Return additional info if validating

if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser()
    ap.add_argument("-i", "--image", type=str, required=True, help="path to input image")
    ap.add_argument("-east", "--east", type=str, required=False, help="path to input EAST text detector")
    ap.add_argument("-d", "--device", type=str, default="olympus_cv_1500", help="device name is required to set the correct text settings")
    ap.add_argument("-v", "--validation", type=bool, default=False, help="Boolean value representing if validation through the AGL-Validator is required.")
    ap.add_argument("-c", "--min-confidence", type=float, default=0.5, help="minimum probability required to inspect a region")
    ap.add_argument("-w", "--width", type=int, default=320, help="resized image width (should be multiple of 32)")
    ap.add_argument("-e", "--height", type=int, default=320, help="resized image height (should be multiple of 32)")
    args = vars(ap.parse_args())

    main(args["image"], args["east"], args["device"], args["validation"], args["min_confidence"], args["width"], args["height"])
