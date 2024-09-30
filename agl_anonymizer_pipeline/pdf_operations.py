from pypdf import PdfReader, PdfWriter
#from reportlab.lib.pagesizes import letter
#from reportlab.pdfgen import canvas
import numpy as np
from PIL import Image
import cv2

def convert_pdf_page_to_image(page):
    """
    Convert a single PDF page into an image using PyMuPDF and then encode it using OpenCV.
    """
    pix = page.get_pixmap()
    img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, 3)
    return img

def merge_pdfs(pdf_paths, output_path):
    """Merge multiple PDFs into a single PDF."""
    pdf_writer = PdfWriter()
    for path in pdf_paths:
        pdf_reader = PdfReader(path)
        for page in pdf_reader.pages:
            pdf_writer.add_page(page)
    with open(output_path, 'wb') as out:
        pdf_writer.write(out)

# CHANGED letter
def convert_image_to_pdf(image_path, pdf_path, letter_width=612, letter_height=792):
    """Converts an image to a PDF with letter-sized pages."""
    # Letter size in points (1 point = 1/72 inch)
    #letter_width, letter_height = 612, 792  # 8.5 x 11 inches

    # Create a new PDF writer
    pdf_writer = PdfWriter()

    # Open the image and convert it to grayscale
    img = Image.open(image_path).convert('L')

    # Calculate the aspect ratio of the image
    aspect_ratio = img.width / img.height

    # Calculate the width and height of the PDF page based on the aspect ratio and letter size
    if aspect_ratio > 1:
        page_width = letter_width
        page_height = int(letter_width / aspect_ratio)
    else:
        page_width = int(letter_height * aspect_ratio)
        page_height = letter_height

    # Create a new PDF page with the calculated width and height
    pdf_page = pdf_writer.add_blank_page(width=page_width, height=page_height)

    # Convert the image to a numpy array
    img_array = np.array(img)

    # Convert the numpy array to a grayscale image
    gray_img = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)

    # Convert the grayscale image to a binary image using Otsu's thresholding
    _, binary_img = cv2.threshold(gray_img, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)

    # Convert the binary image to a PIL image
    pil_img = Image.fromarray(binary_img)

    # Resize the PIL image to fit the PDF page
    pil_img = pil_img.resize((page_width, page_height))

    # Convert the PIL image back to a numpy array
    img_array = np.array(pil_img)

    # Convert the numpy array to a PIL image
    pil_img = Image.fromarray(img_array)

    # Convert the PIL image to a PDF image
    pdf_img = Image.frombytes('L', pil_img.size, pil_img.tobytes())

    # Add the PDF image to the PDF page
    pdf_page.merge_page(pdf_img)

    # Save the PDF file
    with open(pdf_path, 'wb') as f:
        pdf_writer.write(f)

def convert_image_to_pdf(image_path, pdf_path, letter_width=612, letter_height=792):
    """Converts an image to a PDF with letter-sized pages."""
    # Letter size in points (1 point = 1/72 inch)
    #letter_width, letter_height = 612, 792  # 8.5 x 11 inches

    # Create a new PDF writer
    pdf_writer = PdfWriter()

    # Open the image and convert it to grayscale
    img = Image.open(image_path).convert('L')

    # Calculate the aspect ratio of the image
    aspect_ratio = img.width / img.height

    # Calculate the width and height of the PDF page based on the aspect ratio and letter size
    if aspect_ratio > 1:
        page_width = letter_width
        page_height = int(letter_width / aspect_ratio)
    else:
        page_width = int(letter_height * aspect_ratio)
        page_height = letter_height

    # Create a new PDF page with the calculated width and height
    pdf_page = pdf_writer.add_blank_page(width=page_width, height=page_height)

    # Convert the image to a numpy array
    img_array = np.array(img)

    # Convert the numpy array to a grayscale image
    gray_img = cv2.cvtColor(img_array, cv2.COLOR_RGB2GRAY)

    # Convert the grayscale image to a binary image using Otsu's thresholding
    _, binary_img = cv2.threshold(gray_img, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)

    # Convert the binary image to a PIL image
    pil_img = Image.fromarray(binary_img)

    # Resize the PIL image to fit the PDF page
    pil_img = pil_img.resize((page_width, page_height))

    # Convert the PIL image back to a numpy array
    img_array = np.array(pil_img)

    # Convert the numpy array to a PIL image
    pil_img = Image.fromarray(img_array)

    # Convert the PIL image to a PDF image
    pdf_img = Image.frombytes('L', pil_img.size, pil_img.tobytes())

    # Add the PDF image to the PDF page
    pdf_page.merge_page(pdf_img)

    # Save the PDF file
    with open(pdf_path, 'wb') as f:
        pdf_writer.write(f)

def convert_pdf_to_images(pdf_path):
    """Convert a PDF file to a list of images."""
    images = []
    pdf_reader = PdfReader(pdf_path)
    for page in pdf_reader.pages:
        img = convert_pdf_page_to_image(page)
        images.append(img)
    return images