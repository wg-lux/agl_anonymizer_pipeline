from PyPDF2 import PdfReader, PdfWriter
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
import numpy as np
from PIL import Image
import fitz

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

def convert_image_to_pdf(image_path, pdf_path):
    """Converts an image to a PDF."""
    c = canvas.Canvas(pdf_path, pagesize=letter)
    img = Image.open(image_path)
    c.drawImage(image_path, 0, 0, width=img.width, height=img.height)
    c.showPage()
    c.save()

def convert_pdf_to_images(pdf_data):
    """Convert a PDF file to a list of images."""
    images = []
    with fitz.open(stream=pdf_data, filetype="pdf") as doc:
        for page in doc:
            img = convert_pdf_page_to_image(page)
            images.append(img)
    return images