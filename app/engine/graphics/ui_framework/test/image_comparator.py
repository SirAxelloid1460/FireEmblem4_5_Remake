import os

from PIL import Image, ImageChops

OUTPUT_DIRECTORY = 'test_output/'
EXPECTED_DIRECTORY = 'expected_output/'

def images_equal(image_name):
    test = Image.open(os.path.join(OUTPUT_DIRECTORY, image_name))
    expected = Image.open(os.path.join(EXPECTED_DIRECTORY, image_name))
    return ImageChops.difference(test, expected).getbbox() is None

def save(image, image_name):
    import pygame
    pygame.image.save(image, os.path.join(OUTPUT_DIRECTORY, image_name))