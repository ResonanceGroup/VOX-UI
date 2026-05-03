"""
validator.py — Device & Property Name Resolver

Maps natural-language device names and property names to canonical
backend device_id and property keys.

Used by tools.py to resolve what the LLM asks for (e.g., "the battery",
"main lights", "soc") into what the backend actually expects ("bank2", "soc").

Design:
  - Primary lookup: DeviceMap (curated aliases → device_id)
  - Fallback: fuzzy matching via difflib.get_close_matches
  - Disambiguation: bank1 vs bank2, inverter1 vs inverter2
  - list_devices(): returns human-readable device catalog for the LLM

Usage:
    resolver = DeviceResolver()
    device_id = resolver.resolve_device("the battery")   # → "bank2"
    device_id = resolver.resolve_device("main lights")   # → "main_lights"
    prop = resolver.resolve_property("bank2", "state of charge") # → "soc"
    devices = resolver.list_devices()   # → list of {id, name, category}
"""

from __future__ import annotations

import logging
from difflib import get_close_matches
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Device catalog
# From: config/devices.json on the dashboard Pi
# ---------------------------------------------------------------------------

DEVICE_CATALOG: List[Dict] = [
    # Power
    {"id": "bank1",             "name": "Battery Bank 1 (Renogy LFP)",          "category": "power"},
    {"id": "bank2",             "name": "Battery Bank 2 (EcoFlow DELTA)",        "category": "power"},
    {"id": "inverter1",         "name": "Inverter 1 (Renogy)",                   "category": "power"},
    {"id": "inverter2",         "name": "Inverter 2 (EcoFlow AC output)",        "category": "power"},
    {"id": "alternator_charger","name": "Alternator Charger (Renogy DCC1212)",   "category": "power"},
    {"id": "shore_power",       "name": "Shore Power",                           "category": "power"},
    {"id": "solar",             "name": "Solar (Wanderer MPPT)",                 "category": "power"},
    {"id": "ac_charger",        "name": "AC Charger (MeanWell NPB-450)",         "category": "power"},
    # HVAC
    {"id": "climate",           "name": "Climate Sensor",                        "category": "hvac"},
    {"id": "fan",               "name": "Vent Fan",                              "category": "hvac"},
    {"id": "furnace",           "name": "Furnace",                               "category": "hvac"},
    # Lighting
    {"id": "main_lights",       "name": "Main Lights",                           "category": "lighting"},
    {"id": "galley_lights",     "name": "Galley Lights",                         "category": "lighting"},
    # Water
    {"id": "water",             "name": "Water Pump / Tank Levels",              "category": "water"},
    # Other
    {"id": "obd_reader",        "name": "OBD Reader (vehicle data)",             "category": "other"},
    {"id": "printer",           "name": "Receipt Printer",                       "category": "other"},
]

# Canonical device IDs for fast lookup
_ALL_DEVICE_IDS: List[str] = [d["id"] for d in DEVICE_CATALOG]

# ---------------------------------------------------------------------------
# Device name → device_id alias map
# Covers common natural-language variations an LLM might produce
# ---------------------------------------------------------------------------

DEVICE_ALIASES: Dict[str, str] = {
    # Battery — default to bank2 (EcoFlow, primary)
    "battery":              "bank2",
    "the battery":          "bank2",
    "main battery":         "bank2",
    "ecoflow":              "bank2",
    "ecoflow battery":      "bank2",
    "bank2":                "bank2",
    "battery bank 2":       "bank2",
    # Battery bank1 (Renogy, secondary)
    "bank1":                "bank1",
    "renogy battery":       "bank1",
    "battery bank 1":       "bank1",
    "battery 1":            "bank1",
    "renogy":               "bank1",
    # Inverter — default to inverter1 (Renogy, relay-controlled household inverter)
    "inverter":             "inverter1",
    "the inverter":         "inverter1",
    "renogy inverter":      "inverter1",
    "inverter1":            "inverter1",
    "inverter 1":           "inverter1",
    # Inverter 2 (EcoFlow AC output)
    "ecoflow inverter":     "inverter2",
    "inverter2":            "inverter2",
    "inverter 2":           "inverter2",
    "ecoflow ac":           "inverter2",
    # Solar
    "solar":                "solar",
    "solar panel":          "solar",
    "solar panels":         "solar",
    "solar power":          "solar",
    "mppt":                 "solar",
    # Shore power / grid
    "shore power":          "shore_power",
    "shore":                "shore_power",
    "grid":                 "shore_power",
    "ac power":             "shore_power",
    "plugged in":           "shore_power",
    # Chargers
    "ac charger":           "ac_charger",
    "battery charger":      "ac_charger",
    "meanwell":             "ac_charger",
    "alternator charger":   "alternator_charger",
    "alternator":           "alternator_charger",
    "dc charger":           "alternator_charger",
    # Lights
    "main lights":          "main_lights",
    "main light":           "main_lights",
    "lights":               "main_lights",
    "the lights":           "main_lights",
    "overhead lights":      "main_lights",
    "ceiling lights":       "main_lights",
    "galley lights":        "galley_lights",
    "galley light":         "galley_lights",
    "kitchen lights":       "galley_lights",
    "kitchen light":        "galley_lights",
    # Fan
    "fan":                  "fan",
    "vent fan":             "fan",
    "vent":                 "fan",
    "roof fan":             "fan",
    "the fan":              "fan",
    # Furnace / heat
    "furnace":              "furnace",
    "heater":               "furnace",
    "heat":                 "furnace",
    "heating":              "furnace",
    # Climate / sensors
    "climate":              "climate",
    "temperature":          "climate",
    "inside temperature":   "climate",
    "cabin temperature":    "climate",
    "humidity":             "climate",
    "temp":                 "climate",
    "thermometer":          "climate",
    # Water
    "water":                "water",
    "water pump":           "water",
    "pump":                 "water",
    "the pump":             "water",
    "tank":                 "water",
    "water tank":           "water",
    "fresh water":          "water",
    "grey water":           "water",
    "black water":          "water",
    # OBD
    "obd":                  "obd_reader",
    "vehicle":              "obd_reader",
    "engine":               "obd_reader",
    "rpm":                  "obd_reader",
    "speed":                "obd_reader",
    # Printer
    "printer":              "printer",
    "receipt printer":      "printer",
    "print":                "printer",
}

# ---------------------------------------------------------------------------
# Property name → property key maps, per device category
# ---------------------------------------------------------------------------

# Common property aliases (used as fallback for any device)
_COMMON_PROPERTY_ALIASES: Dict[str, str] = {
    "on":           "activated",
    "off":          "activated",
    "active":       "activated",
    "enabled":      "enabled",
    "state":        "state",
    "status":       "state",
}

# Device-specific property aliases
PROPERTY_ALIASES: Dict[str, Dict[str, str]] = {
    "bank1": {
        "soc":              "soc",
        "state of charge":  "soc",
        "charge":           "soc",
        "voltage":          "voltage",
        "volts":            "voltage",
        "current":          "current",
        "amps":             "current",
        "power":            "power",
        "watts":            "power",
        "temperature":      "temperature",
        "temp":             "temperature",
        "state":            "state",
        "time to go":       "estimated_run_time",
        "runtime":          "estimated_run_time",
        "run time":         "estimated_run_time",
        "time remaining":   "estimated_run_time",
        "charge time":      "estimated_charge_time",
    },
    "bank2": {
        # Same as bank1
        "soc":              "soc",
        "state of charge":  "soc",
        "charge":           "soc",
        "voltage":          "voltage",
        "volts":            "voltage",
        "current":          "current",
        "amps":             "current",
        "power":            "power",
        "watts":            "power",
        "temperature":      "temperature",
        "temp":             "temperature",
        "state":            "state",
        "time to go":       "estimated_run_time",
        "runtime":          "estimated_run_time",
        "time remaining":   "estimated_run_time",
    },
    "inverter1": {
        "activated":        "activated",
        "on":               "activated",
        "off":              "activated",
        "output voltage":   "output_voltage",
        "output current":   "output_current",
        "output power":     "output_power",
        "power":            "output_power",
        "watts":            "output_power",
    },
    "inverter2": {
        "activated":        "activated",
        "on":               "activated",
        "output power":     "output_power",
        "power":            "output_power",
    },
    "solar": {
        "input voltage":    "input_voltage",
        "input power":      "input_power",
        "output voltage":   "output_voltage",
        "output power":     "output_power",
        "voltage":          "input_voltage",
        "power":            "input_power",
        "watts":            "input_power",
        "state":            "state",
        "temperature":      "temperature",
    },
    "main_lights": {
        "activated":        "activated",
        "on":               "activated",
        "brightness":       "brightness",
        "dim":              "brightness",
        "level":            "brightness",
    },
    "galley_lights": {
        "activated":        "activated",
        "on":               "activated",
        "brightness":       "brightness",
        "dim":              "brightness",
        "level":            "brightness",
    },
    "climate": {
        "cabin temperature":        "cabin_temperature",
        "inside temperature":       "cabin_temperature",
        "indoor temperature":       "cabin_temperature",
        "temperature":              "cabin_temperature",
        "cabin temp":               "cabin_temperature",
        "inside temp":              "cabin_temperature",
        "external temperature":     "external_temperature",
        "outside temperature":      "external_temperature",
        "outdoor temperature":      "external_temperature",
        "outside temp":             "external_temperature",
        "cabin humidity":           "cabin_humidity",
        "inside humidity":          "cabin_humidity",
        "humidity":                 "cabin_humidity",
        "external humidity":        "external_humidity",
        "outside humidity":         "external_humidity",
        "mode":                     "mode",
        "set temperature":          "set_temperature",
        "setpoint":                 "set_temperature",
        "target temperature":       "set_temperature",
    },
    "fan": {
        "on":               "activated",
        "off":              "activated",
        "activated":        "activated",
    },
    "furnace": {
        "on":               "enabled",
        "enabled":          "enabled",
        "activated":        "activated",
        "running":          "activated",
        "setpoint":         "setpoint",
        "set temperature":  "setpoint",
        "target":           "setpoint",
    },
    "water": {
        "pump":             "pump_activated",
        "pump on":          "pump_activated",
        "pump activated":   "pump_activated",
        "fresh":            "fresh_level",
        "fresh water":      "fresh_level",
        "fresh level":      "fresh_level",
        "grey":             "grey_level",
        "grey water":       "grey_level",
        "gray water":       "grey_level",
        "grey level":       "grey_level",
        "black":            "black_level",
        "black water":      "black_level",
        "black level":      "black_level",
        "tank levels":      "fresh_level",  # default to fresh
    },
    "shore_power": {
        "connected":        "connected",
        "plugged in":       "connected",
        "voltage":          "voltage",
        "current":          "current",
        "power":            "power",
    },
    "obd_reader": {
        "engine":           "engine_running",
        "running":          "engine_running",
        "rpm":              "rpm",
        "speed":            "speed",
        "coolant":          "coolant_temp",
        "coolant temp":     "coolant_temp",
        "engine temp":      "coolant_temp",
        "battery":          "battery_voltage",
        "fuel":             "fuel_level",
        "fuel level":       "fuel_level",
    },
}

# ---------------------------------------------------------------------------
# DeviceResolver
# ---------------------------------------------------------------------------

_FUZZY_CUTOFF = 0.6
_FUZZY_N = 3


class ResolveError(Exception):
    """Raised when a device or property name cannot be resolved."""
    pass


class DeviceResolver:
    """
    Resolves natural-language device and property names to canonical IDs.

    Usage:
        resolver = DeviceResolver()
        device_id = resolver.resolve_device("the battery")    # → "bank2"
        prop      = resolver.resolve_property("bank2", "soc") # → "soc"
        devices   = resolver.list_devices()
    """

    def resolve_device(self, name: str) -> str:
        """
        Resolve a natural-language device name to a canonical device_id.

        Strict mode: only exact matches auto-resolve.
        
        Order:
          1. Exact match in DEVICE_ALIASES (case-insensitive) → resolve automatically
          2. Exact match against device_ids → resolve automatically
          3. No fuzzy auto-resolve: return top 3 suggestions for LLM to choose from

        Returns:
            Canonical device_id (e.g., "bank2", "main_lights")

        Raises:
            ResolveError with suggestions if no exact match found
        """
        key = name.lower().strip()

        # 1. Alias exact match
        if key in DEVICE_ALIASES:
            resolved = DEVICE_ALIASES[key]
            logger.debug(f"resolve_device: '{name}' → '{resolved}' (alias)")
            return resolved

        # 2. Direct device_id match
        if key in _ALL_DEVICE_IDS:
            logger.debug(f"resolve_device: '{name}' → '{key}' (direct)")
            return key

        # 3. Get fuzzy suggestions for the LLM to disambiguate
        candidates = list(DEVICE_ALIASES.keys()) + _ALL_DEVICE_IDS
        matches = get_close_matches(key, candidates, n=_FUZZY_N, cutoff=_FUZZY_CUTOFF)

        if matches:
            suggestions = [DEVICE_ALIASES.get(m, m) for m in matches]
            logger.info(f"resolve_device: ambiguous '{name}' — suggestions: {suggestions}")
            raise ResolveError(
                f"I'm not sure which device you mean by '{name}'. "
                f"Did you mean one of these? "
                f"{', '.join([self._get_friendly_name(s) for s in suggestions])}. "
                f"Please clarify."
            )

        # 4. No match at all
        raise ResolveError(
            f"Device '{name}' not recognized. "
            f"Available devices: {', '.join(_ALL_DEVICE_IDS)}"
        )
    
    def _get_friendly_name(self, device_id: str) -> str:
        """Get the friendly name for a device_id."""
        for d in DEVICE_CATALOG:
            if d["id"] == device_id:
                return d["name"]
        return device_id

    def resolve_property(self, device_id: str, prop_name: str) -> str:
        """
        Resolve a natural-language property name to the canonical key for a device.

        Falls back to returning the raw prop_name if no alias found
        (lets the backend validate it and return an appropriate error).

        Returns:
            Canonical property key (e.g., "soc", "activated", "cabin_temperature")
        """
        key = prop_name.lower().strip()

        # Device-specific lookup
        dev_props = PROPERTY_ALIASES.get(device_id, {})
        if key in dev_props:
            return dev_props[key]

        # Common fallback
        if key in _COMMON_PROPERTY_ALIASES:
            return _COMMON_PROPERTY_ALIASES[key]

        # Return as-is and let backend/caller handle unknown property
        logger.debug(f"resolve_property: no alias for '{prop_name}' on '{device_id}', using as-is")
        return prop_name

    def suggest_devices(self, name: str, n: int = 3) -> List[str]:
        """Return fuzzy suggestions for a device name (for error messages)."""
        key = name.lower().strip()
        candidates = list(DEVICE_ALIASES.keys()) + _ALL_DEVICE_IDS
        matches = get_close_matches(key, candidates, n=n, cutoff=0.4)
        # Resolve aliases to device_ids
        return list(dict.fromkeys(
            DEVICE_ALIASES.get(m, m) for m in matches
        ))

    def list_devices(self) -> List[Dict]:
        """
        Return the full device catalog for the list_devices tool.

        Returns:
            List of {id, name, category} dicts
        """
        return list(DEVICE_CATALOG)

    def get_device_info(self, device_id: str) -> Optional[Dict]:
        """Get catalog entry for a specific device_id."""
        for d in DEVICE_CATALOG:
            if d["id"] == device_id:
                return d
        return None
