import unittest
from lambdas.data_quality import validate_item, validate_json_line

class TestDataQuality(unittest.TestCase):
    def test_valid_item(self):
        item = {"user_id": "abc123", "timestamp": 1234567890}
        valid, err = validate_item(item)
        self.assertTrue(valid)
        self.assertIsNone(err)

    def test_missing_user_id(self):
        item = {"timestamp": 1234567890}
        valid, err = validate_item(item)
        self.assertFalse(valid)
        self.assertIn("Missing required field: user_id", err)

    def test_invalid_user_id_type(self):
        item = {"user_id": 123, "timestamp": 1234567890}
        valid, err = validate_item(item)
        self.assertFalse(valid)
        self.assertIn("user_id must be a non-empty string", err)

    def test_missing_timestamp(self):
        item = {"user_id": "abc123"}
        valid, err = validate_item(item)
        self.assertFalse(valid)
        self.assertIn("Missing required field: timestamp", err)

    def test_invalid_timestamp_type(self):
        item = {"user_id": "abc123", "timestamp": "not_a_number"}
        valid, err = validate_item(item)
        self.assertFalse(valid)
        self.assertIn("timestamp must be a number", err)

    def test_valid_json_line(self):
        line = '{"user_id": "abc123", "timestamp": 1234567890}'
        valid, err = validate_json_line(line)
        self.assertTrue(valid)
        self.assertIsNone(err)

    def test_invalid_json_line(self):
        line = '{user_id: "abc123", "timestamp": 1234567890}'  # Invalid JSON
        valid, err = validate_json_line(line)
        self.assertFalse(valid)
        self.assertIn("Invalid JSON", err)

if __name__ == "__main__":
    unittest.main()
