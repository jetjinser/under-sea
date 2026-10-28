import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "update_vm", Path(__file__).with_name("vm.py"))
vm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vm)


class VMTests(unittest.TestCase):
    def test_opencode_lines_share_vm_test(self):
        self.assertEqual(
            vm.test_expression("opencode-v1"),
            "(@ (under-sea tests opencode) %test-under-sea-opencode)")
        self.assertEqual(vm.test_expression("opencode-v2"),
                         vm.test_expression("opencode-v1"))

    def test_unknown_package_fails(self):
        with self.assertRaises(SystemExit):
            vm.test_expression("kilocode")


if __name__ == "__main__":
    unittest.main()
