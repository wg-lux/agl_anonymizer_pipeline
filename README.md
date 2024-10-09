# AGL Anonymizer Pipeline

This Module is designed to work with the Django API AGL Anonymizer.


The Submodule is used to provide automatic anonymization of sensitive information. It is a three step pipeline using Text Region Detection (EAST), OCR (Optical Character Recognition, Tesseract, TrOCR) and Named Entity Recognition (flair-ner, gender-guessr). This tool is particularly useful in scenarios where sensitive information needs to be removed or replaced from images or documents while retaining the overall context and visual structure.

## Features

- **Text detection and anonymization**: Utilizes advanced OCR techniques to detect text in images and applies anonymizing to safeguard sensitive information.
- **Blurring Functionality**: Offers customizable blurring options to obscure parts of an image, providing an additional layer of privacy.
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

Text Region Detection: EAST and Tesseract are applied to find the text regions in the image.
OCR Module: Detects and extracts text from images using Tesseract and TROCR
Anonymizer Module: Applies Pseudonyms to the sensitive text regions identified. A custom names directory is provided.
Blur Module: Provides functions to blur specific areas in the image.
Save Module: Handles the saving of processed images in a chosen format.

## Contributing

Contributions to the AGL Anonymizer Pipeline are welcome! If you have suggestions for improvements or bug fixes, please open an issue or a pull request.

TO DO:

- UTF-8 Handling of Names - CV2 putText only works in ASCII
- Improving the text region detection by Model Training
- You can customize the behavior of AGL Anonymizer by modifying the parameters in the config.py file (if included). This includes adjusting the OCR sensitivity, blur intensity, and more.


## License

This project is licensed under the MIT License.

## Contact

For any inquiries or assistance with AGL Anonymizer, please contact Max Hild at Maxhild10@gmail.com.
