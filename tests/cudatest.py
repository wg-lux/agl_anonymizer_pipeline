import pytest
import tensorflow as tf

def test_gpu():
    assert tf.test.is_gpu_available()

def test_gpu_count():
    assert len(tf.config.experimental.list_physical_devices('GPU')) == 1