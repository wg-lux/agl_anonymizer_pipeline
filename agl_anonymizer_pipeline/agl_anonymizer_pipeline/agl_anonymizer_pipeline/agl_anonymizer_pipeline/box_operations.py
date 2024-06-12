from .color_picker_avg import get_dominant_color
import numpy as np

def extend_boxes_if_needed(image, boxes, extension_margin=10, color_threshold=30):
    extended_boxes = []
    for box in boxes:
        (startX, startY, endX, endY) = box

        # Get the dominant color of the current box
        dominant_color = get_dominant_color(image, box)

        # Check the color signal around the box and decide if extension is needed
        # Check above the box
        if startY - extension_margin > 0:
            upper_region_color = get_dominant_color(image, (startX, startY - extension_margin, endX, startY))
            if np.linalg.norm(np.array(upper_region_color) - np.array(dominant_color)) > color_threshold:
                startY = max(startY - extension_margin, 0)

        # Check below the box
        if endY + extension_margin < image.shape[0]:
            lower_region_color = get_dominant_color(image, (startX, endY, endX, endY + extension_margin))
            if np.linalg.norm(np.array(lower_region_color) - np.array(dominant_color)) > color_threshold:
                endY = min(endY + extension_margin, image.shape[0])

        # Check left of the box
        if startX - extension_margin > 0:
            left_region_color = get_dominant_color(image, (startX - extension_margin, startY, startX, endY))
            if np.linalg.norm(np.array(left_region_color) - np.array(dominant_color)) > color_threshold:
                startX = max(startX - extension_margin, 0)

        # Check right of the box
        if endX + extension_margin < image.shape[1]:
            right_region_color = get_dominant_color(image, (endX, startY, endX + extension_margin, endY))
            if np.linalg.norm(np.array(right_region_color) - np.array(dominant_color)) > color_threshold:
                endX = min(endX + extension_margin, image.shape[1])

        # Add the possibly extended box to the list
        extended_boxes.append((startX, startY, endX, endY))

    return extended_boxes
