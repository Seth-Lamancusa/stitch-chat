"""
Test file containing information about Antigravity's favorite fruit and an example class.
"""

import unittest

# Information about Antigravity's favorite fruit: The Anti-Gravity Apple
FAVORITE_FRUIT_INFO = {
    "name": "Anti-Gravity Apple",
    "scientific_name": "Malus domesticus levitatus",
    "description": (
        "Unlike the classical apple that fell on Sir Isaac Newton's head to inspire the theory of "
        "gravity, the Anti-Gravity Apple falls upwards. It is extremely buoyant, sweet, "
        "and is known to induce a feeling of weightlessness when consumed."
    ),
    "key_benefits": [
        "Defies standard gravitational pull",
        "Rich in vitamins and levitation properties",
        "Perfect for high-altitude baking"
    ]
}


class AntiGravityFruitField:
    """
    An example class representing a field of anti-gravity fruits.
    Provides methods to simulate fruit levitation and harvesting.
    """

    def __init__(self, fruit_name: str, upward_acceleration: float = 9.81):
        self.fruit_name = fruit_name
        self.upward_acceleration = upward_acceleration  # m/s^2, falling upwards!
        self.fruits_count = 10

    def harvest_fruit(self) -> str:
        if self.fruits_count > 0:
            self.fruits_count -= 1
            return f"Harvested one delicious {self.fruit_name}."
        return f"No {self.fruit_name}s left! They have all drifted into the stratosphere."

    def calculate_altitude(self, seconds: float) -> float:
        """
        Calculates how high a fruit has levitated after a given number of seconds,
        assuming a starting altitude of 0 meters and constant upward acceleration.
        """
        if seconds < 0:
            raise ValueError("Time cannot be negative.")
        return 0.5 * self.upward_acceleration * (seconds ** 2)


class TestAntiGravityFruit(unittest.TestCase):
    """
    Test suite for the AntiGravityFruitField class.
    """

    def setUp(self):
        self.field = AntiGravityFruitField(
            fruit_name=FAVORITE_FRUIT_INFO["name"],
            upward_acceleration=9.81
        )

    def test_fruit_info(self):
        # Verify our favorite fruit information is structured correctly
        self.assertEqual(FAVORITE_FRUIT_INFO["name"], "Anti-Gravity Apple")
        self.assertIn("defies", FAVORITE_FRUIT_INFO["description"].lower())

    def test_harvest_fruit(self):
        # Verify harvesting decrements fruit count
        self.assertEqual(self.field.fruits_count, 10)
        result = self.field.harvest_fruit()
        self.assertEqual(self.field.fruits_count, 9)
        self.assertIn("Harvested one", result)

    def test_harvest_all_fruits(self):
        # Empty the field
        for _ in range(10):
            self.field.harvest_fruit()
        self.assertEqual(self.field.fruits_count, 0)
        
        # Trying to harvest when empty should return the drifting warning
        result = self.field.harvest_fruit()
        self.assertIn("drifted into the stratosphere", result)

    def test_calculate_altitude(self):
        # d = 0.5 * a * t^2
        # For t = 2s, a = 9.81 -> d = 0.5 * 9.81 * 4 = 19.62
        self.assertAlmostEqual(self.field.calculate_altitude(2.0), 19.62)

    def test_invalid_time_raises_error(self):
        with self.assertRaises(ValueError):
            self.field.calculate_altitude(-1.0)


if __name__ == "__main__":
    unittest.main()
