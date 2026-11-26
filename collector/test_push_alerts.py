"""Tests for the push alert rules: python3 -m unittest collector/test_push_alerts.py"""
import unittest

from push_alerts import COOLDOWN_HOURS, detect

H = 3600


def f(on, mx, name="Zellbury"):
    return {"name": name, "on_sale": on, "max_off": mx}


class Detect(unittest.TestCase):
    def test_first_sight_remembers_without_alert(self):
        alerts, st = detect({}, {"z": f(0, 0)}, "quick", now=0)
        self.assertEqual(alerts, [])
        self.assertEqual(st["z"], {"on": False, "max": 0, "last": 0})

    def test_sale_start_alerts_in_quick_mode(self):
        _, st = detect({}, {"z": f(0, 0)}, "full", now=0)
        alerts, st = detect(st, {"z": f(37, 50)}, "quick", now=10 * H)
        self.assertEqual(alerts[0]["title"], "Zellbury sale is live!")
        self.assertEqual(alerts[0]["body"], "Up to 50% off. Tap to see the deals.")
        self.assertTrue(st["z"]["on"])

    def test_sale_start_full_mode_includes_count(self):
        alerts, _ = detect({"z": {"on": False, "max": 0, "last": 0}}, {"z": f(1250, 60)}, "full", now=10 * H)
        self.assertIn("1,250 items on sale, up to 60% off", alerts[0]["body"])

    def test_no_repeat_while_sale_continues(self):
        st = {"z": {"on": True, "max": 50, "last": 0}}
        alerts, _ = detect(st, {"z": f(400, 52)}, "quick", now=10 * H)
        self.assertEqual(alerts, [])

    def test_bigger_discount_alerts(self):
        st = {"z": {"on": True, "max": 50, "last": 0}}
        alerts, st2 = detect(st, {"z": f(400, 70)}, "quick", now=10 * H)
        self.assertEqual(alerts[0]["title"], "Zellbury: bigger discounts")
        self.assertEqual(st2["z"]["max"], 70)

    def test_quick_mode_never_ends_a_sale(self):
        st = {"z": {"on": True, "max": 50, "last": 0}}
        _, st2 = detect(st, {"z": f(0, 0)}, "quick", now=10 * H)
        self.assertTrue(st2["z"]["on"])

    def test_full_mode_ends_sale_then_next_start_alerts(self):
        st = {"z": {"on": True, "max": 50, "last": 0}}
        _, st = detect(st, {"z": f(0, 0)}, "full", now=10 * H)
        self.assertFalse(st["z"]["on"])
        alerts, _ = detect(st, {"z": f(30, 40)}, "quick", now=20 * H)
        self.assertEqual(len(alerts), 1)

    def test_cooldown_stops_back_to_back_alerts(self):
        st = {"z": {"on": False, "max": 0, "last": 0}}
        alerts, st = detect(st, {"z": f(30, 40)}, "quick", now=10 * H)
        self.assertEqual(len(alerts), 1)
        alerts, _ = detect(st, {"z": f(300, 60)}, "quick", now=10 * H + 3600)
        self.assertEqual(alerts, [], "within cooldown")
        alerts, _ = detect(st, {"z": f(300, 60)}, "quick", now=10 * H + COOLDOWN_HOURS * H + 1)
        self.assertEqual(len(alerts), 1, "after cooldown")


if __name__ == "__main__":
    unittest.main()
