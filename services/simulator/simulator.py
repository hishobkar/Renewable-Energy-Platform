"""
Telemetry Simulator – generates realistic IoT data for renewable energy assets
and posts it to the Telemetry Service at a configurable interval.
"""
import os
import time
import math
import random
import logging
import requests
from datetime import datetime, timezone

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("simulator")

TELEMETRY_URL = os.getenv("TELEMETRY_SERVICE_URL", "http://localhost:5002")
ASSET_URL = os.getenv("ASSET_SERVICE_URL", "http://localhost:5001")
INTERVAL = float(os.getenv("SIMULATION_INTERVAL_SECONDS", "5"))
ANOMALY_RATE = float(os.getenv("ANOMALY_RATE", "0.05"))  # 5% chance of injecting anomaly

# ─── Asset definitions ────────────────────────────────────────────────────────

ASSETS = [
    {"id": "11111111-0000-0000-0000-000000000001", "name": "North Wind Farm Alpha",  "type": "WindTurbine"},
    {"id": "11111111-0000-0000-0000-000000000002", "name": "Solar Park Beta",        "type": "SolarFarm"},
    {"id": "11111111-0000-0000-0000-000000000003", "name": "Wind Turbine Gamma",     "type": "WindTurbine"},
    {"id": "11111111-0000-0000-0000-000000000004", "name": "Hydro Station Delta",    "type": "HydroElectric"},
    {"id": "11111111-0000-0000-0000-000000000005", "name": "Battery Storage Epsilon","type": "BatteryStorage"},
]

# ─── Signal generators ────────────────────────────────────────────────────────

def _sin_wave(tick: int, period: float, amplitude: float, offset: float, noise: float = 0.02) -> float:
    base = offset + amplitude * math.sin(2 * math.pi * tick / period)
    return base + random.gauss(0, noise * amplitude)

def _clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))

def generate_metrics(asset: dict, tick: int, anomaly: bool) -> dict:
    t = asset["type"]

    if t == "WindTurbine":
        wind_speed    = _clamp(_sin_wave(tick, 288, 6, 10), 0, 25)  # 0–25 m/s
        rotor_speed   = _clamp(wind_speed * 0.7 + random.gauss(0, 0.3), 0, 20)
        power_output  = _clamp(rotor_speed * 4.5 + random.gauss(0, 0.5), 0, 100)
        temperature   = _clamp(_sin_wave(tick, 576, 10, 45, 0.03), 20, 80)
        vibration     = _clamp(abs(random.gauss(0.5, 0.2)), 0, 5)
        if anomaly:
            temperature = random.uniform(75, 95)  # overheating
            vibration   = random.uniform(4.5, 8)  # excessive vibration
        return {
            "wind_speed": round(wind_speed, 2),
            "rotor_speed": round(rotor_speed, 2),
            "power_output": round(power_output, 2),
            "temperature": round(temperature, 2),
            "vibration": round(vibration, 3),
        }

    elif t == "SolarFarm":
        hour = (tick % 288) / 12.0  # 0–24 scale
        solar_irr = max(0.0, _clamp(math.sin(math.pi * (hour - 6) / 12) * 900 + random.gauss(0, 30), 0, 1200))
        power_out = solar_irr * 0.055 + random.gauss(0, 0.5)
        temperature = 20 + solar_irr / 40 + random.gauss(0, 1)
        voltage = _clamp(random.gauss(230, 2), 200, 250)
        current = _clamp(power_out * 4.3, 0, 500)
        if anomaly:
            solar_irr = random.uniform(0, 50)  # shading / soiling event
            power_out *= 0.1
        return {
            "solar_irr": round(max(0, solar_irr), 1),
            "power_output": round(max(0, power_out), 2),
            "temperature": round(temperature, 1),
            "voltage": round(voltage, 1),
            "current": round(max(0, current), 1),
        }

    elif t == "HydroElectric":
        flow_rate = _clamp(_sin_wave(tick, 1440, 40, 80, 0.02), 20, 200)
        power_output = flow_rate * 0.28 + random.gauss(0, 0.3)
        head_pressure = _clamp(random.gauss(45, 2), 30, 60)
        temperature = _clamp(random.gauss(18, 1), 10, 30)
        if anomaly:
            flow_rate = random.uniform(5, 15)  # drought / blockage
        return {
            "flow_rate": round(flow_rate, 1),
            "power_output": round(max(0, power_output), 2),
            "head_pressure": round(head_pressure, 1),
            "temperature": round(temperature, 1),
        }

    else:  # BatteryStorage
        soc = _clamp(_sin_wave(tick, 576, 30, 60, 0.01), 10, 100)  # state of charge %
        voltage = 370 + soc * 0.6 + random.gauss(0, 1)
        current = _clamp(random.gauss(0, 80), -400, 400)  # neg = charging
        temperature = _clamp(random.gauss(28, 2), 10, 60)
        if anomaly:
            temperature = random.uniform(55, 75)  # thermal runaway warning
        return {
            "state_of_charge": round(soc, 1),
            "voltage": round(voltage, 1),
            "current": round(current, 1),
            "temperature": round(temperature, 1),
        }

# ─── Main loop ────────────────────────────────────────────────────────────────

def wait_for_service(url: str, name: str, retries: int = 30, delay: float = 5.0):
    for i in range(retries):
        try:
            r = requests.get(f"{url}/health", timeout=5)
            if r.status_code == 200:
                logger.info("%s is ready", name)
                return
        except Exception:
            pass
        logger.info("Waiting for %s… (%d/%d)", name, i + 1, retries)
        time.sleep(delay)
    logger.warning("%s did not become ready – continuing anyway", name)

def post_telemetry(asset: dict, metrics: dict) -> bool:
    payload = {
        "asset_id": asset["id"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "type": asset["type"],
        "metrics": metrics,
        "source": "simulator",
        "quality": 1.0,
    }
    try:
        r = requests.post(f"{TELEMETRY_URL}/api/v1/telemetry", json=payload, timeout=10)
        r.raise_for_status()
        return True
    except Exception as exc:
        logger.error("POST telemetry failed for %s: %s", asset["name"], exc)
        return False

def main():
    logger.info("Telemetry Simulator starting (interval=%.1fs, anomaly_rate=%.0f%%)",
                INTERVAL, ANOMALY_RATE * 100)

    wait_for_service(TELEMETRY_URL, "Telemetry Service")

    tick = 0
    while True:
        for asset in ASSETS:
            is_anomaly = random.random() < ANOMALY_RATE
            metrics = generate_metrics(asset, tick, is_anomaly)
            ok = post_telemetry(asset, metrics)
            tag = "[ANOMALY] " if is_anomaly else ""
            if ok:
                logger.info("%s%s → %s", tag, asset["name"], {k: f"{v:.2f}" for k, v in metrics.items()})

        tick += 1
        time.sleep(INTERVAL)

if __name__ == "__main__":
    main()
