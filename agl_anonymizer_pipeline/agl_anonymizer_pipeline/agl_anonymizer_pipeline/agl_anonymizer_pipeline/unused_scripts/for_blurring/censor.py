import cv2
from color_picker_avg import get_dominant_color

def expand_roi(startX, startY, endX, endY, expansion, image_shape):
    """
    Expand the ROI by a certain number of pixels in all directions and ensure it is within image boundaries.

    Parameters:
    startX, startY, endX, endY: int
        The starting and ending coordinates of the ROI.
    expansion: int
        The number of pixels to expand the ROI in all directions.
    image_shape: tuple
        The shape of the image to ensure the expanded ROI is within the bounds.

    Returns:
    tuple
        The expanded ROI coordinates.
    """
    startX = max(0, startX - expansion)
    startY = max(0, startY - expansion)
    endX = min(image_shape[1], endX + expansion)
    endY = min(image_shape[0], endY + expansion)
    return (startX, startY, endX, endY)

def blur_function(image, boxes, expansion=10, blur_strength=(51, 51), rectangle_scale=0.8):
    """
    Apply a strong Gaussian blur to each ROI in the image and slightly extend the blur outside the ROI.

    Parameters:
    image: ndarray
        The image on which to apply the blurring.
    boxes: list of tuple
        The list of bounding boxes where each box is a tuple of (startX, startY, endX, endY).
    expansion: int
        The number of pixels to expand the blur beyond the ROI.
    blur_strength: tuple
        The size of the Gaussian kernel to use for blurring.

    Returns:
    None
    """
    
    for (startX, startY, endX, endY) in boxes:
        # Expand the ROI to include a border around the detected region
        original_roi = image[startY:endY, startX:endX]

        (startX, startY, endX, endY) = expand_roi(startX, startY, endX, endY, expansion, image.shape)

        # Extract the expanded ROI from the image
        roi = image[startY:endY, startX:endX]
        # Calculate the dominant color in the original (non-expanded) ROI
        dominant_color = get_dominant_color(image, (startX, startY, endX, endY))

        # Calculate the dimensions for the smaller rectangle
        rect_width = int((endX - startX) * rectangle_scale)
        rect_height = int((endY - startY) * rectangle_scale)
        rect_startX = startX + (endX - startX - rect_width) // 2
        rect_startY = startY + (endY - startY - rect_height) // 2

        # Draw the rectangle on the blurred image
        cv2.rectangle(image, (rect_startX, rect_startY), (rect_startX + rect_width, rect_startY + rect_height), dominant_color, -1)

        # Apply a strong Gaussian blur to the ROI
        blurred_roi = cv2.GaussianBlur(roi, blur_strength, 0)

        # Replace the original image's ROI with the blurred one
        image[startY:endY, startX:endX] = blurred_roi

    # Save or display the modified image
    cv2.imwrite('blurred_image.jpg', image)
    # cv2.imshow('Blurred Image', image)
    # cv2.waitKey(0)
    # cv2.destroyAllWindows()