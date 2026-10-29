import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_qwenimage", Path(__file__).with_name("qwenimage.py"))
qwen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qwen)


class QwenImageTests(unittest.TestCase):
    def test_pins_are_read_without_network(self):
        result = qwen.report(network=False)
        self.assertEqual(result["package"], "qwenimage")
        self.assertEqual(result["pins"]["main_version"], "20261010")
        self.assertEqual(
            result["pins"]["ncnn_commit"],
            "c6b351b56fbe32e0381ae00331e3df649b20d7b7")
        self.assertEqual(result["submodule"]["status"], "unknown")


if __name__ == "__main__":
    unittest.main()
