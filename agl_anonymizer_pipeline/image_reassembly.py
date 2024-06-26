import cv2
import os
import uuid

def reassemble_image(modified_images_map, output_dir, id, original_image_path=None):
    curr_image_path = None
    original_image = None

    for ((box_key, original_image_path), modified_image_path) in modified_images_map.items():
        if curr_image_path is None or original_image_path != curr_image_path:
            original_image = cv2.imread(original_image_path)
            curr_image_path = original_image_path

            if original_image is None:
                print(f"Warning: Could not load original image from {original_image_path}. Skipping this image.")
                continue

        modified_image = cv2.imread(modified_image_path)
        if modified_image is None:
            print(f"Warning: Could not load modified image from {modified_image_path}. Skipping this modification.")
            continue

        startX, startY, endX, endY = map(int, box_key[0].split(','))

        # Prevent the bounding box from starting outside the original image
        startX = max(startX, 0)
        startY = max(startY, 0)

        # Ensure the bounding box fits within the original image dimensions
        startX = min(startX, original_image.shape[1] - modified_image.shape[1])
        startY = min(startY, original_image.shape[0] - modified_image.shape[0])

        # Calculate the effective overlay dimensions
        overlay_height = min(modified_image.shape[0], original_image.shape[0] - startY)
        overlay_width = min(modified_image.shape[1], original_image.shape[1] - startX)

        # Ensure the overlay dimensions are valid
        if overlay_height <= 0 or overlay_width <= 0:
            print(f"Invalid overlay dimensions: overlay_height={overlay_height}, overlay_width={overlay_width}. Skipping this modification.")
            continue

        # Overlay the modified image onto the original image within the effective dimensions
        original_image[startY:startY + overlay_height, startX:startX + overlay_width] = modified_image[:overlay_height, :overlay_width]

    if original_image is not None:
        final_image_path = os.path.join(output_dir, f"reassembled_image_{id}_{uuid.uuid4()}.jpg")
        cv2.imwrite(final_image_path, original_image)
        print(f"Reassembled image saved to: {final_image_path}")
    elif original_image_path is not None:
        final_image_path = os.path.join(output_dir, f"reassembled_image_{id}_{uuid.uuid4()}.jpg")
        cv2.imwrite(final_image_path, cv2.imread(original_image_path))
        print(f"No modifications were made. Copying the original image to the output directory: {final_image_path}")
    else:
        print("No original image was successfully loaded.")

    return final_image_path if original_image is not None else None
