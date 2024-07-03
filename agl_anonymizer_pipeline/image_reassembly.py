import cv2
import os
import uuid

def reassemble_image(modified_images_map, output_dir, id, original_image_path=None):
    # Load the original image only once
    curr_image = cv2.imread(original_image_path)
    if curr_image is None:
        print(f"Warning: Could not load original image from {original_image_path}.")
        return None

    for ((box_key, original_image_path), modified_image_path) in modified_images_map.items():
        modified_image = cv2.imread(modified_image_path)
        if modified_image is None:
            print(f"Warning: Could not load modified image from {modified_image_path}. Skipping this modification.")
            continue

        startX, startY, endX, endY = map(int, box_key[0].split(','))

        # Ensure the bounding box fits within the original image dimensions
        startX = max(min(startX, curr_image.shape[1] - modified_image.shape[1]), 0)
        startY = max(min(startY, curr_image.shape[0] - modified_image.shape[0]), 0)
        endX = min(startX + modified_image.shape[1], curr_image.shape[1])
        endY = min(startY + modified_image.shape[0], curr_image.shape[0])

        overlay_width = endX - startX
        overlay_height = endY - startY

        # Check if calculated dimensions are valid
        if overlay_width <= 0 or overlay_height <= 0:
            print("Invalid overlay dimensions, skipping this modification.")
            continue

        # Overlay the modified image onto the current image within the effective dimensions
        curr_image[startY:endY, startX:endX] = modified_image[0:overlay_height, 0:overlay_width]

    # Save the final reassembled image
    final_image_path = os.path.join(output_dir, f"reassembled_image_{id}_{uuid.uuid4()}.jpg")
    cv2.imwrite(final_image_path, curr_image)
    print(f"Reassembled image saved to: {final_image_path}")

    return final_image_path

# Example usage
if __name__ == "__main__":
    modified_images_map = {
        # Example structure, populate with actual data
        (('100,100,200,200', 'original_image_path.jpg'), 'modified_image_path1.jpg'): 'modified_image_path1.jpg',
        (('150,150,250,250', 'original_image_path.jpg'), 'modified_image_path2.jpg'): 'modified_image_path2.jpg'
    }
    output_dir = 'output_directory'
    id = 'example_id'
    original_image_path = 'original_image_path.jpg'

    reassemble_image(modified_images_map, output_dir, id, original_image_path)
