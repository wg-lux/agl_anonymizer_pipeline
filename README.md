# agl_anonymizer_pipeline

agl_anonymizer_pipeline is a comprehensive Python API designed for image processing with specific functionalities for anonymizing, saving, blurring, and OCR (Optical Character Recognition). This tool is particularly useful in scenarios where sensitive information needs to be redacted from images or documents while retaining the overall context and visual structure.


The AGL Anonymizer Pipeline is a comprehensive Python module designed for image processing with specific functionalities for anonymization using common german names, saving, blurring, and OCR (Optical Character Recognition). This tool is particularly useful in scenarios where sensitive information needs to be redacted from images or documents while retaining the overall context and visual structure.

## Features

- **Text detection and anonymization**: Utilizes advanced OCR techniques to detect text in images and applies anonymizing to safeguard sensitive information.
- **Blurring Functionality**: Offers customizable blurring options to obscure parts of an image, providing an additional layer of privacy.
- **Image Saving**: Efficiently saves processed images in a desired format, maintaining high-quality output.
- **Extensive Format Support**: Capable of handling various image and document formats for a wide range of applications.

## Installation

To get started with AGL Anonymizer, clone this repository and install the required dependencies.

git clone https://github.com/maxhild/agl_anonymizer_pipeline.git
cd agl_anonymizer_pipeline
nix develop
dowload a text detection model like frozen_east_text_detection.pb and place it inside the agl_anonymizer_pipeline folder.


## Usage

To use AGL Anonymizer Pipeline, follow these steps:

Prepare Your Images: Place the images you want to process in the designated folder.
Configure Settings: Adjust the settings in the configuration file (if applicable) to suit your anonymizing and blurring needs.
Run the Module: Execute the main script from the command line to process the images.
bash

code:

python main.py --image images/your_image.jpg --east frozen_east_text_detection.pb 

example:

python main.py --image images/lebron_james.jpg --east frozen_east_text_detection.pb 

## Modules

AGL Anonymizer is comprised of several key modules:

OCR Module: Detects and extracts text from images.
Anonymizer Module: Applies anonymizing techniques to identified sensitive text regions.
Blur Module: Provides functions to blur specific areas in the image.
Save Module: Handles the saving of processed images in a chosen format.
Customization

You can customize the behavior of AGL Anonymize by modifying the parameters in the main function call. 

## Contributing

Contributions to AGL Anonymizer are welcome! If you have suggestions for improvements or bug fixes, please open an issue or a pull request.

## License

This project is licensed under the MIT License.

## Contact

For any inquiries or assistance with AGL Anonymizer, please contact Max Hild at Maxhild10@gmail.com.


## Installation

To get started with AGL anonymizer, clone this repository and install the required dependencies. Nix and Poetry should install the dependencies automatically.

The package is also available on pip through:

pip install agl_anonymizer_pipeline

git clone https://github.com/wg-lux/agl_anonymizer_pipeline.git

## Usage

To use AGL anonymizer, follow these steps:

Prepare Your Images: Place the images you want to process in the designated folder.
Configure Settings: Adjust the settings in the configuration file (if applicable) to suit your anonymizing and blurring needs.
Run the Module: Execute the main script to process the images.

```bash
python main.py --image images/lebron_james.jpg --east frozen_east_text_detection.pb 
```

## Parameters of the `main` function

The `main` function is responsible for processing either images or PDF files through the AGL Anonymizer pipeline. Below are the parameters it accepts:

- **image_or_pdf_path** (`str`):  
   The path to the input image or PDF that you want to process. This can be a single image file or a multi-page PDF. The function will detect the file type and process accordingly.

- **east_path** (`str`, optional):  
   Path to the pre-trained EAST text detection model (`frozen_east_text_detection.pb`). If not provided, the function will expect it to be in the designated location in the AGL Anonymizer setup.

- **device** (`str`, optional):  
   The device name used to set the correct OCR and NER (Named Entity Recognition) text settings for different devices. Defaults to `olympus_cv_1500`.

- **validation** (`bool`, optional):  
   If set to `True`, the function will perform additional validation by using an external AGL-Validator service to validate the results and return extra output. Defaults to `False`.

- **min_confidence** (`float`, optional):  
   Minimum confidence level for detecting text regions within the image. Regions with a confidence score below this threshold will not be processed. Defaults to `0.5`.

- **width** (`int`, optional):  
   Resized width for the image, used for text detection. It should be a multiple of 32. Defaults to `320`.

- **height** (`int`, optional):  
   Resized height for the image, used for text detection. It should be a multiple of 32. Defaults to `320`.

### Example usage of the `main` function:
```python
main(
    image_or_pdf_path="path/to/your/file.pdf",
    east_path="path/to/frozen_east_text_detection.pb",
    device="olympus_cv_1500",
    validation=True,
    min_confidence=0.6,
    width=640,
    height=640
)
```

# Modules

AGL Anonymizer is comprised of several key modules:

## OCR Pipeline Manager Module

The **OCR Pipeline Manager** module coordinates the Optical Character Recognition (OCR) and Named Entity Recognition (NER) processes for images and PDFs. It uses multiple OCR techniques (such as Tesseract and TrOCR), applies NER for detecting sensitive information, and replaces detected names with pseudonyms using the names generator. This module is essential for extracting and anonymizing text from input files.

### Key Components

1. **OCR and NER Functions**:
   - **`trocr_on_boxes(img_path, boxes)`**:  
     Uses the TrOCR model for OCR on specific regions (boxes) in the image.
   - **`tesseract_on_boxes(img_path, boxes)`**:  
     Uses Tesseract OCR for detecting text within the provided boxes.
   - **`NER_German(text)`**:  
     Applies Named Entity Recognition (NER) on the extracted text to identify entities such as names (tagged as `PER` for persons).

2. **Text Detection**:
   - **`east_text_detection(img_path, east_path, min_confidence, width, height)`**:  
     Uses the EAST text detection model to identify potential text regions in the image.
   - **`tesseract_text_detection(img_path, min_confidence, width, height)`**:  
     Uses Tesseract's built-in text detection to identify text regions in the image.

3. **Name Handling**:
   - **`gender_and_handle_full_names(words, box, image_path, device)`**:  
     Replaces full names in detected text with pseudonyms based on gender predictions.
   - **`gender_and_handle_separate_names(words, first_name_box, last_name_box, image_path, device)`**:  
     Handles cases where first and last names are detected separately in the image.
   - **`gender_and_handle_device_names(words, box, image_path, device)`**:  
     Handles the names associated with specific medical devices.

4. **Image Processing**:
   - **`blur_function(image_path, box, background_color)`**:  
     Blurs specific regions (text boxes) in an image, typically for anonymization.
   - **`convert_pdf_to_images(pdf_path)`**:  
     Converts a PDF document into individual images for processing.

5. **Combining Text Boxes**:
   - **`combine_boxes(text_with_boxes)`**:  
     Merges adjacent text boxes if they belong to the same line and are close together.

6. **Helper Functions**:
   - **`find_or_create_close_box(phrase_box, boxes, image_width, offset=60)`**:  
     Finds or creates a bounding box that is close to the existing text box, useful when handling names or phrases that may extend beyond the detected region.
   - **`process_text(extracted_text)`**:  
     Cleans up extracted text, removing excess line breaks and spaces.

### Main Functionality

#### `process_images_with_OCR_and_NER(file_path, east_path, device, min_confidence, width, height)`

This is the core function of the module, which handles the entire OCR and NER pipeline for a given file (image or PDF). It performs the following steps:
- Detects and reads text from the file using EAST and Tesseract models.
- Applies OCR (TrOCR and Tesseract) to the detected text regions.
- Uses NER to identify sensitive information (e.g., names) in the text.
- Replaces detected names with pseudonyms using the names generator.
- Optionally blurs specified regions in the image, such as detected names.
- Outputs a modified version of the image with anonymized text and a CSV file containing the NER results.

##### Parameters:
- **`file_path`** (`str`): The path to the input image or PDF file.
- **`east_path`** (`str`, optional): The path to the EAST model used for text detection.
- **`device`** (`str`, optional): Specifies the device configuration for text handling and name pseudonymization. Defaults to `"default"`.
- **`min_confidence`** (`float`, optional): The minimum confidence level required for text detection. Defaults to `0.5`.
- **`width`** (`int`, optional): The width to resize the image for text detection. Defaults to `320`.
- **`height`** (`int`, optional): The height to resize the image for text detection. Defaults to `320`.

##### Returns:
- **`modified_images_map`** (`dict`): A map of the modified images with replaced text.
- **`result`** (`dict`): Contains detailed results of the OCR and NER processes, including:
  - `filename`: The original file name.
  - `file_type`: The type of the file (image or PDF).
  - `extracted_text`: The raw extracted text from the file.
  - `names_detected`: A list of detected names.
  - `combined_results`: The OCR and NER results.
  - `modified_images_map`: A map of modified images with pseudonymized text.
  - `gender_pars`: List of gender classifications used in the pseudonymization process.

### Example Usage

```python
file_path = "your_file_path.jpg"
modified_images_map, result = process_images_with_OCR_and_NER(
    file_path, 
    east_path="path/to/frozen_east_text_detection.pb",
    device="default", 
    min_confidence=0.6, 
    width=640, 
    height=640
)
for res in result['combined_results']:
    print(res)


## Names Generator Module

The Names Generator module is responsible for assigning gender-specific or neutral names to detected text boxes in images. It uses the gender guesser tool to determine the likely gender of a first name and then selects an appropriate full name from predefined lists of male, female, and neutral names. This process enhances the anonymization workflow by replacing potentially sensitive text with randomized names while preserving the gender or neutrality of the original text.

### Key Components

1. **Gender Guesser**:  
   This tool predicts the gender of the given first name using the `gender_guesser.detector` module. Based on the first name, it returns one of the following values:
   - `male`
   - `mostly_male`
   - `female`
   - `mostly_female`
   - `unknown`
   - `andy` (for androgynous names)

2. **Name Files**:  
   The module uses text files containing ASCII-formatted first and last names:
   - `first_and_last_names_female_ascii.txt`
   - `first_and_last_names_male_ascii.txt`
   - `first_names_female_ascii.txt`
   - `last_names_female_ascii.txt`
   - `first_names_male_ascii.txt`
   - `last_names_male_ascii.txt`
   - `first_names_neutral_ascii.txt`
   - `last_names_neutral_ascii.txt`

   These files are loaded during initialization to provide randomized name selection based on gender.

3. **Functions**:
   - **`gender_and_handle_full_names(words, box, image_path, device)`**:  
     This function handles full names extracted from the image. It determines the gender from the first name and then selects a random full name (first and last) from the appropriate list.
     - Input: Words list, bounding box of text, image path.
     - Output: Processed image path with a pseudonymized name added and the guessed gender.
   
   - **`gender_and_handle_separate_names(words, first_name_box, last_name_box, image_path, device)`**:  
     This function deals with cases where first and last names are separated in the image. It processes the names individually, applies gender guessing, and adds the pseudonymized name to the image.
     - Input: Words list, bounding boxes for first and last name, image path.
     - Output: Processed image path with pseudonymized separate names and the guessed gender.

   - **`gender_and_handle_device_names(words, box, image_path, device)`**:  
     This function works similarly to the full names handler but focuses on names generated by specific medical devices.
     - Input: Words list, bounding box of text, image path, and device name.
     - Output: Image with pseudonymized names based on device-specific rules.

4. **Name Formatting**:
   - **`format_name(name, format_string)`**:  
     This function formats the given name based on the specified device’s formatting rules. For example, it can reorder first and last names depending on the requirements.

5. **Text Rendering**:
   - The module provides several functions for drawing and fitting text to an image. The drawn names are centered, scaled, and resized to fit within the given bounding boxes. Examples include:
     - **`draw_text_with_line_break`**: Renders text with line breaks.
     - **`draw_text_without_line_break`**: Renders text without line breaks.
     - **`draw_text_to_fit`**: Scales and positions text to fit inside a bounding box.

### Example Usage

The names generator module is integrated into the anonymization pipeline and automatically handles the detection and replacement of names in images. Here’s how it can be invoked programmatically:

```python
box_to_image_map, gender_guess = gender_and_handle_full_names(
    words=["John", "Doe"],
    box=(50, 50, 300, 100),
    image_path="path/to/image.png",
    device="olympus_cv_1500"
)
```



