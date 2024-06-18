# AGL-anonymizer

AGL-anonymizer is a comprehensive Python API designed for image processing with specific functionalities for anonymizing, saving, blurring, and OCR (Optical Character Recognition). This tool is particularly useful in scenarios where sensitive information needs to be redacted from images or documents while retaining the overall context and visual structure.

It is generally called by sending a request to its API. You can find an example of a request here:



## Features

- **Text Detection and anonymizing**: Utilizes advanced OCR techniques to detect text in images and applies anonymizing to safeguard sensitive information.
- **Blurring Functionality**: Offers customizable blurring options to obscure parts of an image, providing an additional layer of privacy.
- **Image Saving**: Efficiently saves processed images in a desired format, maintaining high-quality output.
- **Extensive Format Support**: Capable of handling various image and document formats for a wide range of applications.

## Installation

To get started with AGL anonymizer, clone this repository and install the required dependencies. Nix and Poetry should install the dependencies automatically

git clone https://github.com/wg-lux/agl_anonymizer.git

## Usage

To use AGL anonymizer, follow these steps:

Prepare Your Images: Place the images you want to process in the designated folder.
Configure Settings: Adjust the settings in the configuration file (if applicable) to suit your anonymizing and blurring needs.
Run the Module: Execute the main script to process the images.
bash
Copy code
python main.py --image images/lebron_james.jpg --east frozen_east_text_detection.pb 

## Modules

AGL Anonymizer is comprised of several key modules:

OCR Module: Detects and extracts text from images.
Anonymizer Module: Applies anonymizering techniques to identified sensitive text regions.
Blur Module: Provides functions to blur specific areas in the image.
Save Module: Handles the saving of processed images in a chosen format.
Customization

You can customize the behavior of AGL Anonymizer by modifying the parameters in the config.py file (if included). This includes adjusting the OCR sensitivity, blur intensity, and more.

## Contributing

Contributions to AGL Anonymizer are welcome! If you have suggestions for improvements or bug fixes, please open an issue or a pull request.

## License

This project is licensed under the MIT License.

## Contact

For any inquiries or assistance with AGL Anonymizer, please contact Max Hild at Maxhild10@gmail.com.
