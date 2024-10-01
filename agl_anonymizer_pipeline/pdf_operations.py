import pymupdf  # PyMuPDF
import numpy as np
import cv2
import os

def convert_pdf_page_to_image(page):
    """
    Convert a single PDF page into an image using PyMuPDF and then encode it using OpenCV.
    """
    pix = page.get_pixmap()
    img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)
    return img

def convert_pdf_to_images(pdf_path):
    """Convert a PDF file to a list of image paths."""
    images = []
    doc = pymupdf.open(pdf_path)
    for page_num in range(len(doc)):
        page = doc[page_num]
        pix = page.get_pixmap()
        image_path = f"{pdf_path}_page_{page_num}.png"
        pix.save(image_path)
        images.append(image_path)
    return images

def merge_pdfs(pdf_paths, output_path):
    """Merge multiple PDFs into a single PDF using PyMuPDF."""
    merged_doc = pymupdf.open()
    for path in pdf_paths:
        doc = pymupdf.open(path)
        merged_doc.insert_pdf(doc)
    merged_doc.save(output_path)

def convert_image_to_pdf(image_path, pdf_path):
    """Converts an image to a PDF using PyMuPDF."""
    img = pymupdf.Pixmap(image_path)
    doc = pymupdf.open()
    rect = img.rect
    page = doc.new_page(width=rect.width, height=rect.height)
    page.insert_image(rect, filename=image_path)
    doc.save(pdf_path)
