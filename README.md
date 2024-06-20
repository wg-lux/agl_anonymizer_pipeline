# AGL Anonymizer Pipeline

This Module is designed to work with the Django API AGL Anonymizer.


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

You can customize the behavior of AGL Anonymize by modifying the parameters in the config.py file (if included). This includes adjusting the OCR sensitivity, blur intensity, and more.

## Contributing

Contributions to the AGL Anonymizer Pipeline are welcome! If you have suggestions for improvements or bug fixes, please open an issue or a pull request.

TO DO:

- UTF-8 Handling of Names
- Improving the text region detection
- Re-adding Tesseract OCR or adding Paddle OCR for improved full text document OCR.

## License

This project is licensed under the MIT License.

## Contact

For any inquiries or assistance with AGL Anonymizer, please contact Max Hild at Maxhild10@gmail.com.
