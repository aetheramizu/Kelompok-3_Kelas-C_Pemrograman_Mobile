import 'package:flutter/material.dart';

/// Ikon Material untuk kode cuaca WMO.
IconData weatherIcon(int code, {bool isDay = true}) {
  switch (code) {
    case 0:
      return isDay ? Icons.wb_sunny : Icons.nightlight_round;
    case 1:
    case 2:
      return Icons.cloud_queue;
    case 3:
      return Icons.cloud;
    case 45:
    case 48:
      return Icons.blur_on;
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
      return Icons.grain;
    case 61:
    case 63:
    case 65:
    case 66:
    case 67:
    case 80:
    case 81:
    case 82:
      return Icons.water_drop;
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return Icons.ac_unit;
    case 95:
    case 96:
    case 99:
      return Icons.flash_on;
    default:
      return Icons.help_outline;
  }
}
