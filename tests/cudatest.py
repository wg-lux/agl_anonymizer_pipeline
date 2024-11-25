import pytest
import tensorflow as tf
import pytest
from pathlib import Path
import cv2
import numpy as np
import torch
from unittest.mock import Mock, patch
import tempfile
import os

@pytest.fixture
def sample_image():
    # Create a simple test image
    img = np.zeros((500, 500, 3), dtype=np.uint8)
    cv2.putText(img, "Test Text", (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
    
    with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp:
        cv2.imwrite(tmp.name, img)
        yield Path(tmp.name)
    
    os.unlink(tmp.name)

@pytest.fixture
def sample_pdf():
    # Create a sample PDF
    with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as tmp:
        # Use reportlab or another library to create a simple PDF
        yield Path(tmp.name)
    
    os.unlink(tmp.name)

# Test main function
def test_main_with_image(sample_image):
    from main import main
    
    result = main(
        str(sample_image),
        east_path=None,
        device="olympus_cv_1500",
        validation=False
    )
    
    assert isinstance(result, (str, Path))
    assert Path(result).exists()

# Test OCR functions
@patch('transformers.ViTImageProcessor.from_pretrained')
@patch('transformers.VisionEncoderDecoderModel.from_pretrained')
@patch('transformers.AutoTokenizer.from_pretrained')
def test_trocr_on_boxes(mock_tokenizer, mock_model, mock_processor, sample_image):
    from ../ocr import trocr_on_boxes
    
    boxes = [(10, 10, 100, 50)]
    
    # Mock the model outputs
    mock_model.return_value.generate.return_value = Mock(
        sequences=torch.tensor([[1, 2, 3]]),
        scores=[torch.tensor([[0.9, 0.1]])]
    )
    
    results, confidences = trocr_on_boxes(sample_image, boxes)
    
    assert len(results) == len(boxes)
    assert len(confidences) == len(boxes)
    assert all(isinstance(conf, float) for conf in confidences)

# Test image processing functions
def test_resize_image(sample_image):
    from ../main import resize_image
    
    original_size = cv2.imread(str(sample_image)).shape[:2]
    resize_image(sample_image, max_width=300, max_height=300)
    new_size = cv2.imread(str(sample_image)).shape[:2]
    
    assert new_size[0] <= 300 and new_size[1] <= 300
    assert new_size[0] / new_size[1] == pytest.approx(original_size[0] / original_size[1], rel=0.1)

# Test PDF handling
def test_get_image_paths(sample_pdf):
    from ../main import get_image_paths
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_dir_path = Path(temp_dir)
        image_paths = get_image_paths(sample_pdf, temp_dir_path)
        
        assert len(image_paths) > 0
        assert all(path.exists() for path in image_paths)
        assert all(path.suffix.lower() in ['.png', '.jpg', '.jpeg'] for path in image_paths)

# Test error handling
def test_main_with_invalid_file():
    from ../main import main
    
    with pytest.raises(FileNotFoundError):
        main("nonexistent_file.jpg")

# Test NER functions
@patch('flair.models.SequenceTagger.load')
def test_split_and_check():
    from ../ocr_pipeline_manager import split_and_check
    
    text = "John Doe is a person"
    entities = split_and_check(text)
    
    assert isinstance(entities, list)
    assert all(isinstance(entity, tuple) for entity in entities)
    assert all(len(entity) == 2 for entity in entities)

# Test integration
def test_process_images_with_OCR_and_NER(sample_image):
    from ../ocr_pipeline_manager import process_images_with_OCR_and_NER
    
    modified_images_map, result = process_images_with_OCR_and_NER(
        str(sample_image),
        device="olympus_cv_1500"
    )
    
    assert isinstance(modified_images_map, dict)
    assert isinstance(result, dict)
    assert 'filename' in result
    assert 'combined_results' in result
    assert 'names_detected' in result

# Test GPU memory management
def test_clear_gpu_memory():
    from ../main import clear_gpu_memory
    
    if torch.cuda.is_available():
        # Allocate some GPU memory
        tensor = torch.zeros(1000, 1000).cuda()
        clear_gpu_memory()
        
        # Check if memory was cleared
        assert torch.cuda.memory_allocated() == 0

# Add conftest.py for shared fixtures

def test_gpu():
    assert tf.test.is_gpu_available()

def test_gpu_count():
    assert len(tf.config.experimental.list_physical_devices('GPU')) == 1